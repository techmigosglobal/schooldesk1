import * as fontkit from "npm:fontkit";
import { PDFDocument, PDFFont, PDFPage, rgb } from "npm:pdf-lib";

export type StructuredExportTable = {
  title: string;
  headers: string[];
  rows: unknown[][];
  weights?: number[];
};

export type StructuredReportPdfInput = {
  title: string;
  schoolName: string;
  branchCode?: string;
  academicYear?: string;
  scope?: string[];
  metrics?: Array<{ label: string; value: string }>;
  tables: StructuredExportTable[];
};

type ScriptFont = {
  pattern: RegExp;
  fileName: string;
};

const scriptFonts: ScriptFont[] = [
  { pattern: /[\u0900-\u097f]/u, fileName: "NotoSansDevanagari.ttf" },
  { pattern: /[\u0980-\u09ff]/u, fileName: "NotoSansBengali.ttf" },
  { pattern: /[\u0a00-\u0a7f]/u, fileName: "NotoSansGurmukhi.ttf" },
  { pattern: /[\u0a80-\u0aff]/u, fileName: "NotoSansGujarati.ttf" },
  { pattern: /[\u0b00-\u0b7f]/u, fileName: "NotoSansOriya.ttf" },
  { pattern: /[\u0b80-\u0bff]/u, fileName: "NotoSansTamil.ttf" },
  { pattern: /[\u0c00-\u0c7f]/u, fileName: "NotoSansTelugu.ttf" },
  { pattern: /[\u0c80-\u0cff]/u, fileName: "NotoSansKannada.ttf" },
  { pattern: /[\u0600-\u06ff]/u, fileName: "NotoSansArabic.ttf" },
];

const pageWidth = 842;
const pageHeight = 595;
const margin = 32;
const footerHeight = 30;
const headerHeight = 64;
const usableWidth = pageWidth - margin * 2;
const dark = rgb(0.04, 0.1, 0.22);
const navy = rgb(0.05, 0.14, 0.31);
const blue = rgb(0.1, 0.31, 0.66);
const muted = rgb(0.29, 0.36, 0.48);
const pale = rgb(0.93, 0.96, 1);
const border = rgb(0.82, 0.87, 0.94);

function cleanText(input: unknown, fallback = "—"): string {
  const value = String(input ?? "")
    .replace(/[\r\n]+/gu, " ")
    .replace(/\s+/gu, " ")
    .trim();
  return value || fallback;
}

async function readBundledFont(fileName: string): Promise<Uint8Array> {
  return await Deno.readFile(new URL(`./assets/${fileName}`, import.meta.url));
}

function splitLongToken(
  token: string,
  maxWidth: number,
  font: PDFFont,
  size: number,
): string[] {
  const chunks: string[] = [];
  let current = "";
  for (const character of Array.from(token)) {
    const candidate = current + character;
    if (current && font.widthOfTextAtSize(candidate, size) > maxWidth) {
      chunks.push(current);
      current = character;
    } else {
      current = candidate;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

function wrapText(
  input: unknown,
  maxWidth: number,
  font: PDFFont,
  size: number,
  maxLines = 8,
): string[] {
  const source = cleanText(input);
  const tokens = source.split(/\s+/u).flatMap((token) =>
    font.widthOfTextAtSize(token, size) <= maxWidth
      ? [token]
      : splitLongToken(token, maxWidth, font, size)
  );
  const lines: string[] = [];
  let line = "";
  for (const token of tokens) {
    const candidate = line ? `${line} ${token}` : token;
    if (!line || font.widthOfTextAtSize(candidate, size) <= maxWidth) {
      line = candidate;
    } else {
      lines.push(line);
      line = token;
    }
  }
  if (line) lines.push(line);
  if (lines.length <= maxLines) return lines;
  const visible = lines.slice(0, maxLines);
  let last = visible[maxLines - 1];
  while (last && font.widthOfTextAtSize(`${last}…`, size) > maxWidth) {
    last = Array.from(last).slice(0, -1).join("");
  }
  visible[maxLines - 1] = `${last}…`;
  return visible;
}

export async function renderStructuredReportPdf(
  input: StructuredReportPdfInput,
): Promise<Uint8Array> {
  const pdf = await PDFDocument.create();
  pdf.registerFontkit(fontkit);
  const baseFont = await pdf.embedFont(
    await readBundledFont("NotoSans.ttf"),
  );
  const embeddedScripts = await Promise.all(
    scriptFonts.map(async (entry) => ({
      ...entry,
      font: await pdf.embedFont(await readBundledFont(entry.fileName)),
    })),
  );
  const fontFor = (value: unknown): PDFFont => {
    const text = cleanText(value, "");
    return embeddedScripts.find((entry) => entry.pattern.test(text))?.font ??
      baseFont;
  };

  const pages: PDFPage[] = [];
  let page: PDFPage;
  let cursorY = 0;

  const drawLines = (
    lines: string[],
    x: number,
    y: number,
    font: PDFFont,
    size: number,
    color = dark,
    lineHeight = size + 2,
  ) => {
    lines.forEach((line, index) => {
      page.drawText(line, { x, y: y - index * lineHeight, font, size, color });
    });
  };

  const startPage = (continuation: boolean) => {
    page = pdf.addPage([pageWidth, pageHeight]);
    pages.push(page);
    page.drawRectangle({
      x: 0,
      y: pageHeight - headerHeight,
      width: pageWidth,
      height: headerHeight,
      color: navy,
    });
    const schoolFont = fontFor(input.schoolName);
    drawLines(
      wrapText(input.schoolName, 380, schoolFont, 17, 1),
      margin,
      pageHeight - 31,
      schoolFont,
      17,
      rgb(1, 1, 1),
    );
    const branch = input.branchCode
      ? `Branch: ${input.branchCode}`
      : "Academic data export";
    const branchFont = fontFor(branch);
    drawLines(
      wrapText(branch, 380, branchFont, 8, 1),
      margin,
      pageHeight - 48,
      branchFont,
      8,
      rgb(0.78, 0.88, 1),
    );
    const headerTitle = continuation ? "Report continued" : input.title;
    const titleFont = fontFor(headerTitle);
    drawLines(
      wrapText(headerTitle, 250, titleFont, 11, 1),
      pageWidth - 290,
      pageHeight - 33,
      titleFont,
      11,
      rgb(1, 1, 1),
    );
    const year = `Academic year: ${
      cleanText(input.academicYear, "Not specified")
    }`;
    const yearFont = fontFor(year);
    drawLines(
      wrapText(year, 250, yearFont, 8, 1),
      pageWidth - 290,
      pageHeight - 48,
      yearFont,
      8,
      rgb(0.78, 0.88, 1),
    );
    cursorY = pageHeight - 88;
  };

  const drawIntro = () => {
    const titleFont = fontFor(input.title);
    drawLines([input.title], margin, cursorY, titleFont, 16, dark);
    cursorY -= 18;
    const scope = (input.scope ?? []).filter(Boolean).join("  •  ") ||
      "School-wide scope";
    const scopeFont = fontFor(scope);
    drawLines(
      wrapText(scope, usableWidth, scopeFont, 8, 2),
      margin,
      cursorY,
      scopeFont,
      8,
      muted,
    );
    cursorY -= 28;
    const metrics = input.metrics ?? [];
    if (!metrics.length) return;
    const metricWidth = usableWidth / metrics.length;
    metrics.forEach((metric, index) => {
      const x = margin + index * metricWidth;
      page.drawRectangle({
        x,
        y: cursorY - 31,
        width: metricWidth - 7,
        height: 30,
        color: pale,
      });
      const labelFont = fontFor(metric.label);
      drawLines(
        wrapText(metric.label, metricWidth - 18, labelFont, 7, 1),
        x + 7,
        cursorY - 10,
        labelFont,
        7,
        muted,
      );
      const valueFont = fontFor(metric.value);
      drawLines(
        wrapText(metric.value, metricWidth - 18, valueFont, 9, 1),
        x + 7,
        cursorY - 23,
        valueFont,
        9,
        dark,
      );
    });
    cursorY -= 45;
  };

  const drawTableHeader = (
    table: StructuredExportTable,
    widths: number[],
  ) => {
    page.drawRectangle({
      x: margin,
      y: cursorY - 20,
      width: usableWidth,
      height: 20,
      color: blue,
    });
    let x = margin;
    table.headers.forEach((label, index) => {
      const font = fontFor(label);
      drawLines(
        wrapText(label, widths[index] - 8, font, 7, 2),
        x + 4,
        cursorY - 8,
        font,
        7,
        rgb(1, 1, 1),
        8,
      );
      x += widths[index];
    });
    cursorY -= 22;
  };

  const beginTableSection = (
    table: StructuredExportTable,
    widths: number[],
    continuation: boolean,
  ) => {
    if (continuation) startPage(true);
    const title = continuation ? `${table.title} (continued)` : table.title;
    const titleFont = fontFor(title);
    drawLines([title], margin, cursorY, titleFont, 11, dark);
    cursorY -= 16;
    drawTableHeader(table, widths);
  };

  startPage(false);
  drawIntro();
  const tables = input.tables.length ? input.tables : [{
    title: "Report data",
    headers: ["Status"],
    rows: [["No data generated"]],
  }];
  for (const table of tables) {
    const headers = table.headers.length ? table.headers : ["Status"];
    const normalizedTable = { ...table, headers };
    const weights = table.weights?.length === headers.length
      ? table.weights
      : headers.map(() => 1);
    const weightTotal = weights.reduce((sum, weight) => sum + weight, 0);
    const widths = weights.map((weight) => usableWidth * weight / weightTotal);
    if (cursorY < 110) startPage(true);
    beginTableSection(normalizedTable, widths, false);
    const rows = table.rows.length
      ? table.rows
      : [["No records match the selected report scope."]];
    rows.forEach((row, rowIndex) => {
      const cellLines = headers.map((_, index) => {
        const value = row[index] ?? "";
        const font = fontFor(value);
        return {
          font,
          lines: wrapText(value, widths[index] - 8, font, 7),
        };
      });
      const lineCount = Math.max(...cellLines.map((cell) => cell.lines.length));
      const rowHeight = Math.max(18, lineCount * 9 + 8);
      if (cursorY - rowHeight < footerHeight + 12) {
        beginTableSection(normalizedTable, widths, true);
      }
      page.drawRectangle({
        x: margin,
        y: cursorY - rowHeight,
        width: usableWidth,
        height: rowHeight,
        color: rowIndex % 2 === 0 ? rgb(0.97, 0.98, 1) : rgb(1, 1, 1),
        borderColor: border,
        borderWidth: 0.5,
      });
      let x = margin;
      cellLines.forEach((cell, index) => {
        drawLines(
          cell.lines,
          x + 4,
          cursorY - 11,
          cell.font,
          7,
          rgb(0.08, 0.13, 0.22),
          9,
        );
        x += widths[index];
      });
      cursorY -= rowHeight;
    });
    cursorY -= 16;
  }

  pages.forEach((pdfPage, index) => {
    page = pdfPage;
    drawLines(
      ["Confidential school record"],
      margin,
      22,
      baseFont,
      8,
      muted,
    );
    drawLines(
      [`Page ${index + 1} of ${pages.length}`],
      pageWidth - 106,
      22,
      baseFont,
      8,
      muted,
    );
  });

  return await pdf.save();
}
