(function () {
  const statusPill = document.getElementById("statusPill");
  const docsList = document.getElementById("docsList");
  const emptyState = document.getElementById("emptyState");
  const emptyBody = document.getElementById("emptyBody");

  function setStatus(text) {
    if (statusPill) statusPill.textContent = text;
  }

  function showEmpty(message) {
    if (emptyBody) emptyBody.textContent = message;
    if (emptyState) emptyState.hidden = false;
  }

  function safeText(s) {
    return (s || "").toString().trim();
  }

  function safeFilenamePart(s) {
    const raw = safeText(s);
    const out = raw.replace(/[^a-zA-Z0-9]+/g, "_").replace(/^_+|_+$/g, "");
    return out || "player";
  }

  function downloadBytes(bytes, filename) {
    const blob = new Blob([bytes], { type: "application/pdf" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 250);
  }

  async function fetchBytes(path) {
    const res = await fetch(path, { cache: "force-cache" });
    if (!res.ok) throw new Error(`Failed to fetch ${path}`);
    return await res.arrayBuffer();
  }

  function bytesFromBase64(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  function imageKindFromBytes(bytes, source) {
    const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    if (
      view.length >= 8 &&
      view[0] === 0x89 &&
      view[1] === 0x50 &&
      view[2] === 0x4e &&
      view[3] === 0x47
    ) {
      return "png";
    }
    if (view.length >= 2 && view[0] === 0xff && view[1] === 0xd8) {
      return "jpg";
    }
    const lower = safeText(source).toLowerCase();
    if (lower.includes("image/jpeg") || lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
      return "jpg";
    }
    return "png";
  }

  async function imageBytesFromSource(source) {
    const value = safeText(source);
    if (!value) throw new Error("Missing image source");
    const dataMatch = value.match(/^data:(image\/(?:png|jpeg|jpg));base64,(.+)$/i);
    if (dataMatch) {
      const bytes = bytesFromBase64(dataMatch[2]);
      return {
        bytes,
        kind: dataMatch[1].toLowerCase().includes("png") ? "png" : "jpg",
      };
    }

    const bytes = await fetchBytes(value);
    return {
      bytes,
      kind: imageKindFromBytes(bytes, value),
    };
  }

  async function embedImage(doc, source, fallbackSource) {
    const candidates = [source, fallbackSource].filter((v, i, a) => safeText(v) && a.indexOf(v) === i);
    for (const candidate of candidates) {
      try {
        const image = await imageBytesFromSource(candidate);
        return image.kind === "jpg"
          ? await doc.embedJpg(image.bytes)
          : await doc.embedPng(image.bytes);
      } catch (_) {
        // Try the next image source.
      }
    }
    return null;
  }

  function drawImageContain(page, image, x, y, width, height) {
    if (!image) return;
    const scale = Math.min(width / image.width, height / image.height);
    const drawW = image.width * scale;
    const drawH = image.height * scale;
    page.drawImage(image, {
      x: x + (width - drawW) / 2,
      y: y + (height - drawH) / 2,
      width: drawW,
      height: drawH,
    });
  }

  function drawFittedText(page, text, options) {
    const value = safeText(text) || "—";
    const { maxWidth, minSize: minSizeOption, ...drawOptions } = options;
    const font = drawOptions.font;
    let size = drawOptions.size;
    const minSize = minSizeOption || Math.max(7, size - 4);
    while (size > minSize && font.widthOfTextAtSize(value, size) > maxWidth) {
      size -= 0.5;
    }
    page.drawText(value, { ...drawOptions, size });
  }

  function nowStampUtc() {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    return (
      d.getUTCFullYear() +
      pad(d.getUTCMonth() + 1) +
      pad(d.getUTCDate()) +
      "-" +
      pad(d.getUTCHours()) +
      pad(d.getUTCMinutes()) +
      pad(d.getUTCSeconds())
    );
  }

  function formatDate(d) {
    try {
      return d.toLocaleDateString("en-IN", {
        day: "2-digit",
        month: "short",
        year: "numeric",
        timeZone: "UTC",
      });
    } catch (_) {
      return d.toISOString().slice(0, 10);
    }
  }

  async function buildIdCardPdf({ playerName, playerId, email, about, kingdom, photo }) {
    if (!window.PDFLib) throw new Error("PDF engine not loaded");
    const { PDFDocument, rgb, StandardFonts } = window.PDFLib;
    const doc = await PDFDocument.create();
    const page = doc.addPage([720, 455]); // Driver-license style landscape card
    const w = page.getWidth();
    const h = page.getHeight();

    const font = await doc.embedFont(StandardFonts.Helvetica);
    const bold = await doc.embedFont(StandardFonts.HelveticaBold);

    const red = rgb(1, 0.156, 0);
    const blue = rgb(0.13, 0.62, 0.98);
    const ink = rgb(0.06, 0.06, 0.06);
    const muted = rgb(0.38, 0.38, 0.38);
    const line = rgb(0.78, 0.78, 0.78);

    page.drawRectangle({
      x: 0,
      y: 0,
      width: w,
      height: h,
      color: rgb(0.95, 0.96, 0.96),
    });
    page.drawRectangle({
      x: 18,
      y: 18,
      width: w - 36,
      height: h - 36,
      color: rgb(1, 1, 1),
      borderColor: ink,
      borderWidth: 2.2,
    });
    page.drawRectangle({ x: 18, y: h - 124, width: w - 36, height: 106, color: ink });
    page.drawRectangle({ x: 18, y: h - 132, width: w - 36, height: 8, color: red });

    const banner = await embedImage(doc, "images/banner.png", "Logo.png");
    if (banner) {
      drawImageContain(page, banner, 42, h - 112, 230, 82);
    } else {
      page.drawText("TEN OF A KIND", {
        x: 44,
        y: h - 82,
        size: 20,
        font: bold,
        color: rgb(1, 1, 1),
      });
    }

    page.drawText("PLAYER ID", {
      x: 310,
      y: h - 70,
      size: 30,
      font: bold,
      color: rgb(1, 1, 1),
    });
    page.drawText("LOCAL DOCUMENT • NOT A GOVERNMENT ID", {
      x: 312,
      y: h - 96,
      size: 9,
      font: bold,
      color: rgb(0.78, 0.84, 0.9),
    });

    const photoX = 520;
    const photoY = 158;
    const photoW = 142;
    const photoH = 174;
    page.drawRectangle({
      x: photoX - 8,
      y: photoY - 8,
      width: photoW + 16,
      height: photoH + 16,
      color: rgb(0.965, 0.965, 0.965),
      borderColor: line,
      borderWidth: 1.2,
    });
    const photoImage = await embedImage(doc, photo, "Renoir.png");
    drawImageContain(page, photoImage, photoX, photoY, photoW, photoH);
    page.drawText("PHOTO", {
      x: photoX + 48,
      y: photoY - 24,
      size: 8,
      font: bold,
      color: muted,
    });

    const labelX = 48;
    const valueX = 168;
    let y = 292;
    const labelSize = 10;
    const valueSize = 17;

    const row = (label, value, valueTextSize = valueSize) => {
      page.drawText(label.toUpperCase(), {
        x: labelX,
        y,
        size: labelSize,
        font: bold,
        color: muted,
      });
      drawFittedText(page, value, {
        x: valueX,
        y: y - 4,
        size: valueTextSize,
        minSize: 9,
        maxWidth: 320,
        font: valueTextSize >= 14 ? bold : font,
        color: ink,
      });
      page.drawLine({
        start: { x: valueX, y: y - 10 },
        end: { x: 486, y: y - 10 },
        thickness: 0.7,
        color: line,
      });
      y -= 46;
    };

    row("Name", playerName || "Player", 19);
    row("Email", email || "—", 12);
    row("Player ID", playerId || "—", 11);
    row("Kingdom", kingdom || "Not set", 13);
    row("About", about || "Ready to win", 12);

    const issued = `Issued: ${formatDate(new Date())}`;
    page.drawText(issued, {
      x: 48,
      y: 42,
      size: 10,
      font,
      color: muted,
    });
    page.drawText("TEN OF A KIND POKER", {
      x: w - 184,
      y: 42,
      size: 10,
      font: bold,
      color: blue,
    });

    return await doc.save();
  }

  async function buildTitleCertificatePdf({ playerName, playerId, kingdomName, titleName }) {
    if (!window.PDFLib) throw new Error("PDF engine not loaded");
    const { PDFDocument, rgb, StandardFonts } = window.PDFLib;
    const doc = await PDFDocument.create();
    const page = doc.addPage([842, 595]); // A4 landscape
    const w = page.getWidth();
    const h = page.getHeight();

    const font = await doc.embedFont(StandardFonts.Helvetica);
    const bold = await doc.embedFont(StandardFonts.HelveticaBold);

    page.drawRectangle({ x: 0, y: 0, width: w, height: h, color: rgb(1, 1, 1) });
    page.drawRectangle({
      x: 22,
      y: 22,
      width: w - 44,
      height: h - 44,
      borderColor: rgb(0, 0, 0),
      borderWidth: 2,
    });

    let renoirPng;
    try {
      const renoirBytes = await fetchBytes("Renoir.png");
      renoirPng = await doc.embedPng(renoirBytes);
    } catch (_) {
      renoirPng = null;
    }

    if (renoirPng) {
      const iw = 240;
      const ih = (renoirPng.height / renoirPng.width) * iw;
      page.drawImage(renoirPng, {
        x: w - iw - 70,
        y: 80,
        width: iw,
        height: ih,
      });
    }

    const red = rgb(1, 0.156, 0);
    const grey = rgb(0.4, 0.4, 0.4);

    const center = (text, size, y, fontRef, color) => {
      const width = fontRef.widthOfTextAtSize(text, size);
      page.drawText(text, { x: w / 2 - width / 2, y, size, font: fontRef, color });
    };

    center("TEN OF A KIND", 16, h - 90, bold, rgb(0, 0, 0));
    center("CERTIFICATE OF TITLE", 30, h - 132, bold, red);

    center("This certifies that", 12, h - 190, font, grey);
    center(playerName || "Player", 34, h - 240, bold, rgb(0, 0, 0));
    center("has earned the title of", 12, h - 280, font, grey);
    center(titleName || "Champion", 26, h - 320, bold, rgb(0, 0, 0));
    center(`in the Kingdom of ${kingdomName || "—"}.`, 12, h - 350, font, grey);

    const certId = `TOK-${nowStampUtc()}-${Math.random().toString(16).slice(2, 10).padEnd(8, "0")}`;
    const issued = `Issued: ${formatDate(new Date())}`;
    const footerY = 52;
    page.drawText(issued, { x: 56, y: footerY, size: 10.5, font, color: grey });
    page.drawText(`Certificate ID: ${certId}`, {
      x: w - 56 - font.widthOfTextAtSize(`Certificate ID: ${certId}`, 10.5),
      y: footerY,
      size: 10.5,
      font,
      color: grey,
    });

    return await doc.save();
  }

  function renderDocItem({ title, desc, onDownload }) {
    const item = document.createElement("div");
    item.className = "docItem";

    const meta = document.createElement("div");
    meta.className = "docMeta";
    const t = document.createElement("div");
    t.className = "docTitle";
    t.textContent = title;
    const d = document.createElement("div");
    d.className = "docDesc";
    d.textContent = desc;
    meta.appendChild(t);
    meta.appendChild(d);

    const btn = document.createElement("button");
    btn.className = "btn";
    btn.type = "button";
    btn.textContent = "Download PDF";
    btn.addEventListener("click", async () => {
      if (btn.disabled) return;
      btn.disabled = true;
      const prev = btn.textContent;
      btn.textContent = "Preparing…";
      setStatus("Preparing…");
      try {
        await onDownload();
        setStatus("Ready");
      } catch (_) {
        setStatus("Failed");
      } finally {
        btn.disabled = false;
        btn.textContent = prev;
      }
    });

    item.appendChild(meta);
    item.appendChild(btn);
    return item;
  }

  const params = new URLSearchParams(window.location.search);
  const uid = safeText(params.get("uid"));
  const name = safeText(params.get("name"));
  const email = safeText(params.get("email"));
  const about = safeText(params.get("about"));
  const kingdom = safeText(params.get("kingdom"));
  const photo = safeText(params.get("photo"));

  let titles = [];
  try {
    const raw = params.get("titles") || "[]";
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) titles = parsed;
  } catch (_) {
    titles = [];
  }

  const displayName = name || (email.includes("@") ? email.split("@")[0] : "Player");

  const userNameEl = document.getElementById("userName");
  const userEmailEl = document.getElementById("userEmail");
  const userUidEl = document.getElementById("userUid");
  if (userNameEl) userNameEl.textContent = displayName;
  if (userEmailEl) userEmailEl.textContent = email || "—";
  if (userUidEl) userUidEl.textContent = uid || "—";

  if (!uid) {
    showEmpty("Open this page from the app to view your documents.");
    setStatus("Guest");
    return;
  }

  const idFilename = `TenOfAKind_ID_${safeFilenamePart(displayName)}_${nowStampUtc()}.pdf`;
  docsList.appendChild(
    renderDocItem({
      title: "ID Card",
      desc: "Driver-license style player card",
      onDownload: async () => {
        const bytes = await buildIdCardPdf({
          playerName: displayName,
          playerId: uid,
          email,
          about,
          kingdom,
          photo,
        });
        downloadBytes(bytes, idFilename);
      },
    })
  );

  const normalizedTitles = [];
  for (const t of titles) {
    if (!t || typeof t !== "object") continue;
    const kingdom = safeText(t.kingdom);
    const titleName = safeText(t.title);
    if (!kingdom || !titleName) continue;
    normalizedTitles.push({ kingdom, titleName });
  }

  if (normalizedTitles.length === 0) {
    showEmpty("No title certificates yet. Win a Title in Career to unlock certificates.");
  } else {
    emptyState.hidden = true;
    normalizedTitles.forEach(({ kingdom, titleName }) => {
      const filename = `TenOfAKind_Title_${safeFilenamePart(kingdom)}_${safeFilenamePart(titleName)}_${nowStampUtc()}.pdf`;
      docsList.appendChild(
        renderDocItem({
          title: `Title Certificate`,
          desc: `${kingdom} — ${titleName}`,
          onDownload: async () => {
            const bytes = await buildTitleCertificatePdf({
              playerName: displayName,
              playerId: uid,
              kingdomName: kingdom,
              titleName,
            });
            downloadBytes(bytes, filename);
          },
        })
      );
    });
  }

  setStatus("Ready");
})();
