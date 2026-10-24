// 生成 Lumina App 图标：1024x1024 PNG（渐变底 + 白色聊天气泡 + 三个点）
const fs = require('fs');
const zlib = require('zlib');
const path = require('path');

const SIZE = 1024;
const SS = 3; // 超采样倍数，用于抗锯齿

// --- CRC32 ---
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td), 0);
  return Buffer.concat([len, td, crc]);
}

// --- 颜色 ---
const C1 = [0x63, 0x66, 0xf1]; // #6366f1
const C2 = [0xa8, 0x55, 0xf7]; // #a855f7
const WHITE = [255, 255, 255];

function bgColor(x, y) {
  // 135deg 渐变：沿 (0,0)->(1,1) 方向做插值，再叠一点径向高光
  let t = (x / SIZE + y / SIZE) / 2;
  t = Math.min(1, Math.max(0, t));
  // 轻微 ease，让中间过渡更柔和
  const e = t * t * (3 - 2 * t);
  let r = C1[0] + (C2[0] - C1[0]) * e;
  let g = C1[1] + (C2[1] - C1[1]) * e;
  let b = C1[2] + (C2[2] - C1[2]) * e;
  // 左上角柔光
  const dx = (x - SIZE * 0.26) / SIZE, dy = (y - SIZE * 0.2) / SIZE;
  const d = Math.sqrt(dx * dx + dy * dy);
  const glow = Math.max(0, 1 - d * 1.9);
  r += (255 - r) * glow * 0.16;
  g += (255 - g) * glow * 0.16;
  b += (255 - b) * glow * 0.16;
  return [r, g, b];
}

// 圆角矩形：中心 (cx,cy)，宽高 w,h，圆角 r
function inRoundedRect(x, y, cx, cy, w, h, r) {
  const dx = Math.max(Math.abs(x - cx) - (w / 2 - r), 0);
  const dy = Math.max(Math.abs(y - cy) - (h / 2 - r), 0);
  return dx * dx + dy * dy <= r * r;
}
function inCircle(x, y, cx, cy, r) {
  const dx = x - cx, dy = y - cy;
  return dx * dx + dy * dy <= r * r;
}
function inTriangle(x, y, ax, ay, bx, by, cx, cy) {
  const d1 = (x - bx) * (ay - by) - (ax - bx) * (y - by);
  const d2 = (x - cx) * (by - cy) - (bx - cx) * (y - cy);
  const d3 = (x - ax) * (cy - ay) - (cx - ax) * (y - ay);
  const neg = d1 < 0 || d2 < 0 || d3 < 0;
  const pos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(neg && pos);
}

// 气泡几何（相对 1024 画布）
const BUB = { cx: 512, cy: 452, w: 560, h: 420, r: 132 };
const TAIL = [402, 636, 566, 636, 404, 792];
const DOTS = [
  { cx: 372, cy: 452, r: 46 },
  { cx: 512, cy: 452, r: 46 },
  { cx: 652, cy: 452, r: 46 },
];

function sample(x, y) {
  let cov = 0; // 白色覆盖率
  const step = 1 / SS;
  const half = step / 2;
  for (let i = 0; i < SS; i++) {
    for (let j = 0; j < SS; j++) {
      const px = x + half + i * step;
      const py = y + half + j * step;
      let hit = false;
      if (inRoundedRect(px, py, BUB.cx, BUB.cy, BUB.w, BUB.h, BUB.r)) hit = true;
      if (!hit && inTriangle(px, py, TAIL[0], TAIL[1], TAIL[2], TAIL[3], TAIL[4], TAIL[5])) hit = true;
      if (hit) {
        // 挖掉三个点（露出渐变底）
        for (const d of DOTS) {
          if (inCircle(px, py, d.cx, d.cy, d.r)) { hit = false; break; }
        }
      }
      if (hit) cov += 1;
    }
  }
  return cov / (SS * SS);
}

// --- 渲染 ---
const raw = Buffer.alloc(SIZE * (SIZE * 3 + 1));
let p = 0;
for (let y = 0; y < SIZE; y++) {
  raw[p++] = 0; // filter: none
  for (let x = 0; x < SIZE; x++) {
    const bg = bgColor(x, y);
    const a = sample(x, y);
    const r = Math.round(bg[0] + (WHITE[0] - bg[0]) * a);
    const g = Math.round(bg[1] + (WHITE[1] - bg[1]) * a);
    const b = Math.round(bg[2] + (WHITE[2] - bg[2]) * a);
    raw[p++] = Math.min(255, Math.max(0, r));
    raw[p++] = Math.min(255, Math.max(0, g));
    raw[p++] = Math.min(255, Math.max(0, b));
  }
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8;  // bit depth
ihdr[9] = 2;  // color type: truecolor RGB
ihdr[10] = 0; // deflate
ihdr[11] = 0; // adaptive filtering
ihdr[12] = 0; // no interlace

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);

const outDir = path.join(__dirname, '..', 'Lumina', 'Assets.xcassets', 'AppIcon.appiconset');
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'Icon-1024.png'), png);
console.log('icon written:', path.join(outDir, 'Icon-1024.png'), png.length, 'bytes');
