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

  async function buildTitleCertificatePdf({ playerName, kingdomName, titleName }) {
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
