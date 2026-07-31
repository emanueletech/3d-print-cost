/*
 * Vista 3D del modello (sostituisce SceneKit dell'app macOS): WebGL puro,
 * nessuna libreria esterna. Le facce che chiederebbero supporti sono rosse.
 */
'use strict';

// tutto racchiuso: nel renderer gli script condividono lo scope globale
(() => {

  const VERT_SRC = `
  attribute vec3 aPos;
  attribute vec3 aNormal;
  attribute float aOverhang;
  uniform mat4 uMVP;
  varying vec3 vNormal;
  varying float vOverhang;
  void main() {
    vNormal = aNormal;
    vOverhang = aOverhang;
    gl_Position = uMVP * vec4(aPos, 1.0);
  }`;

  const FRAG_SRC = `
  precision mediump float;
  varying vec3 vNormal;
  varying float vOverhang;
  void main() {
    vec3 n = normalize(vNormal);
    vec3 key = normalize(vec3(0.45, -0.8, 0.75));
    vec3 fill = normalize(vec3(-0.6, 0.35, 0.4));
    float light = 0.32 + 0.66 * max(dot(n, key), 0.0) + 0.22 * max(dot(n, fill), 0.0);
    vec3 base = mix(vec3(0.47, 0.63, 0.95), vec3(0.98, 0.36, 0.38), vOverhang);
    gl_FragColor = vec4(base * light, 1.0);
  }`;

  const LINE_VERT_SRC = `
  attribute vec3 aPos;
  uniform mat4 uMVP;
  void main() { gl_Position = uMVP * vec4(aPos, 1.0); }`;

  const LINE_FRAG_SRC = `
  precision mediump float;
  uniform vec4 uColor;
  void main() { gl_FragColor = uColor; }`;

  /* ---------- matrici 4×4 (column-major, come le vuole WebGL) ---------- */

  function perspective(fovyDeg, aspect, near, far) {
    const f = 1 / Math.tan((fovyDeg * Math.PI) / 360);
    const nf = 1 / (near - far);
    // prettier-ignore
    return new Float32Array([
      f / aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (far + near) * nf, -1,
      0, 0, 2 * far * near * nf, 0,
    ]);
  }

  function lookAt(eye, center, up) {
    const z = norm3(sub3(eye, center));
    const x = norm3(cross3(up, z));
    const y = cross3(z, x);
    // prettier-ignore
    return new Float32Array([
      x[0], y[0], z[0], 0,
      x[1], y[1], z[1], 0,
      x[2], y[2], z[2], 0,
      -dot3(x, eye), -dot3(y, eye), -dot3(z, eye), 1,
    ]);
  }

  function multiply(a, b) {
    const o = new Float32Array(16);
    for (let c = 0; c < 4; c++)
      for (let r = 0; r < 4; r++)
        o[c * 4 + r] = a[r] * b[c * 4] + a[4 + r] * b[c * 4 + 1] + a[8 + r] * b[c * 4 + 2] + a[12 + r] * b[c * 4 + 3];
    return o;
  }

  const sub3 = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const dot3 = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const cross3 = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  function norm3(v) {
    const l = Math.hypot(v[0], v[1], v[2]) || 1;
    return [v[0] / l, v[1] / l, v[2] / l];
  }

  /* ---------- viewer ---------- */

  class Viewer {
    constructor(canvas) {
      this.canvas = canvas;
      this.gl = canvas.getContext('webgl', { antialias: true, alpha: true });
      this.ok = !!this.gl;
      if (!this.ok) return;

      const gl = this.gl;
      this.prog = this.program(VERT_SRC, FRAG_SRC);
      this.lineProg = this.program(LINE_VERT_SRC, LINE_FRAG_SRC);
      this.buffer = gl.createBuffer();
      this.bedBuffer = gl.createBuffer();
      this.triangles = 0;
      this.bedLines = 0;

      this.theta = -0.9; // rotazione attorno a Z
      this.phi = 1.05; // inclinazione dal piano
      this.distance = 260;
      this.center = [0, 0, 40];

      gl.enable(gl.DEPTH_TEST);
      gl.clearColor(0, 0, 0, 0);

      this.bindInteraction();
      this.resizeObserver = new ResizeObserver(() => this.draw());
      this.resizeObserver.observe(canvas);
    }

    program(vsSrc, fsSrc) {
      const gl = this.gl;
      const compile = (type, src) => {
        const s = gl.createShader(type);
        gl.shaderSource(s, src);
        gl.compileShader(s);
        return s;
      };
      const p = gl.createProgram();
      gl.attachShader(p, compile(gl.VERTEX_SHADER, vsSrc));
      gl.attachShader(p, compile(gl.FRAGMENT_SHADER, fsSrc));
      gl.linkProgram(p);
      return p;
    }

    bindInteraction() {
      let dragging = false;
      let lastX = 0;
      let lastY = 0;
      this.canvas.addEventListener('pointerdown', (e) => {
        dragging = true;
        lastX = e.clientX;
        lastY = e.clientY;
        this.canvas.setPointerCapture(e.pointerId);
      });
      this.canvas.addEventListener('pointermove', (e) => {
        if (!dragging) return;
        this.theta -= (e.clientX - lastX) * 0.01;
        this.phi = Math.max(0.05, Math.min(Math.PI - 0.05, this.phi - (e.clientY - lastY) * 0.01));
        lastX = e.clientX;
        lastY = e.clientY;
        this.draw();
      });
      const stop = (e) => {
        dragging = false;
        if (this.canvas.hasPointerCapture(e.pointerId)) this.canvas.releasePointerCapture(e.pointerId);
      };
      this.canvas.addEventListener('pointerup', stop);
      this.canvas.addEventListener('pointercancel', stop);
      this.canvas.addEventListener(
        'wheel',
        (e) => {
          e.preventDefault();
          this.distance = Math.max(20, Math.min(4000, this.distance * (1 + Math.sign(e.deltaY) * 0.12)));
          this.draw();
        },
        { passive: false }
      );
    }

    /** Carica la mesh (già appoggiata al piatto) e marca le facce da supportare. */
    setMesh(verts, thresholdDeg) {
      if (!this.ok || !verts || !verts.length) return;
      this.verts = verts;
      const b = window.MeshLib.bounds(verts, null);
      this.center = [0, 0, (b.hi[2] - b.lo[2]) / 2];
      const size = Math.max(b.hi[0] - b.lo[0], b.hi[1] - b.lo[1], b.hi[2] - b.lo[2]) || 100;
      this.distance = size * 2.6;
      this.buildBed(size);
      this.setThreshold(thresholdDeg);
    }

    /** Ricalcola solo il colore delle facce quando cambia l'angolo di sbalzo. */
    setThreshold(thresholdDeg) {
      if (!this.ok || !this.verts) return;
      const gl = this.gl;
      const v = this.verts;
      const tris = Math.floor(v.length / 9);
      const data = new Float32Array(tris * 3 * 7);
      const cutoff = Math.cos((thresholdDeg * Math.PI) / 180);
      let w = 0;
      for (let i = 0; i < tris * 9; i += 9) {
        const g = window.MeshLib.faceGeometry(v, i);
        const zmin = Math.min(v[i + 2], v[i + 5], v[i + 8]);
        const over = g.nz < 0 && -g.nz > cutoff && zmin > 0.4 ? 1 : 0;
        for (let k = 0; k < 3; k++) {
          data[w++] = v[i + k * 3];
          data[w++] = v[i + k * 3 + 1];
          data[w++] = v[i + k * 3 + 2];
          data[w++] = g.nx;
          data[w++] = g.ny;
          data[w++] = g.nz;
          data[w++] = over;
        }
      }
      this.triangles = tris;
      gl.bindBuffer(gl.ARRAY_BUFFER, this.buffer);
      gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
      this.draw();
    }

    /** griglia del piatto sotto al modello, per dare la scala */
    buildBed(size) {
      const gl = this.gl;
      const half = Math.max(60, Math.ceil((size * 1.2) / 20) * 20);
      const step = Math.max(10, Math.round(half / 8 / 10) * 10);
      const pts = [];
      for (let x = -half; x <= half; x += step) pts.push(x, -half, 0, x, half, 0);
      for (let y = -half; y <= half; y += step) pts.push(-half, y, 0, half, y, 0);
      this.bedLines = pts.length / 3;
      gl.bindBuffer(gl.ARRAY_BUFFER, this.bedBuffer);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(pts), gl.STATIC_DRAW);
    }

    draw() {
      if (!this.ok) return;
      const gl = this.gl;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = Math.max(1, Math.round(this.canvas.clientWidth * dpr));
      const h = Math.max(1, Math.round(this.canvas.clientHeight * dpr));
      if (this.canvas.width !== w || this.canvas.height !== h) {
        this.canvas.width = w;
        this.canvas.height = h;
      }
      gl.viewport(0, 0, w, h);
      gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
      if (!this.triangles) return;

      const eye = [
        this.center[0] + this.distance * Math.sin(this.phi) * Math.cos(this.theta),
        this.center[1] + this.distance * Math.sin(this.phi) * Math.sin(this.theta),
        this.center[2] + this.distance * Math.cos(this.phi),
      ];
      const mvp = multiply(
        perspective(38, w / h, Math.max(1, this.distance / 100), this.distance * 6),
        lookAt(eye, this.center, [0, 0, 1])
      );

      // piatto
      gl.useProgram(this.lineProg);
      gl.uniformMatrix4fv(gl.getUniformLocation(this.lineProg, 'uMVP'), false, mvp);
      gl.uniform4f(gl.getUniformLocation(this.lineProg, 'uColor'), 0.55, 0.68, 1.0, 0.18);
      const lPos = gl.getAttribLocation(this.lineProg, 'aPos');
      gl.bindBuffer(gl.ARRAY_BUFFER, this.bedBuffer);
      gl.enableVertexAttribArray(lPos);
      gl.vertexAttribPointer(lPos, 3, gl.FLOAT, false, 0, 0);
      gl.drawArrays(gl.LINES, 0, this.bedLines);

      // modello
      gl.useProgram(this.prog);
      gl.uniformMatrix4fv(gl.getUniformLocation(this.prog, 'uMVP'), false, mvp);
      const stride = 7 * 4;
      gl.bindBuffer(gl.ARRAY_BUFFER, this.buffer);
      const aPos = gl.getAttribLocation(this.prog, 'aPos');
      const aNormal = gl.getAttribLocation(this.prog, 'aNormal');
      const aOver = gl.getAttribLocation(this.prog, 'aOverhang');
      gl.enableVertexAttribArray(aPos);
      gl.vertexAttribPointer(aPos, 3, gl.FLOAT, false, stride, 0);
      gl.enableVertexAttribArray(aNormal);
      gl.vertexAttribPointer(aNormal, 3, gl.FLOAT, false, stride, 12);
      gl.enableVertexAttribArray(aOver);
      gl.vertexAttribPointer(aOver, 1, gl.FLOAT, false, stride, 24);
      gl.drawArrays(gl.TRIANGLES, 0, this.triangles * 3);
    }

    destroy() {
      if (this.resizeObserver) this.resizeObserver.disconnect();
    }
  }

  window.Viewer = Viewer;
})();
