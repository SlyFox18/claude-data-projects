// Small helper to build plain, readable Word documents from a list of blocks.
const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType, LevelFormat,
  BorderStyle, Table, TableRow, TableCell, WidthType, ShadingType, Footer, PageNumber,
} = require('docx');

const FONT = 'Calibri';
const ACCENT = '1F4E79';
const PAGE_W = 12240, MARGIN = 1080, CONTENT_W = PAGE_W - 2 * MARGIN; // US Letter, 0.75" margins

// "**bold**" and "`code`" inline markup -> TextRuns
function runs(text, base = {}) {
  const out = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`)/g;
  let last = 0, m;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(new TextRun({ text: text.slice(last, m.index), ...base }));
    const t = m[0];
    if (t.startsWith('**')) out.push(new TextRun({ text: t.slice(2, -2), bold: true, ...base }));
    else out.push(new TextRun({ text: t.slice(1, -1), font: 'Consolas', size: 20, ...base }));
    last = m.index + t.length;
  }
  if (last < text.length) out.push(new TextRun({ text: text.slice(last), ...base }));
  return out;
}

function block(b) {
  if (b.h1) return [new Paragraph({ heading: HeadingLevel.HEADING_1, children: runs(b.h1) })];
  if (b.h2) return [new Paragraph({ heading: HeadingLevel.HEADING_2, children: runs(b.h2) })];
  if (b.h3) return [new Paragraph({ heading: HeadingLevel.HEADING_3, children: runs(b.h3) })];
  if (b.p !== undefined) return [new Paragraph({ spacing: { after: 120 }, keepNext: !!b.keepNext, children: runs(b.p) })];
  if (b.note) return [new Paragraph({
    spacing: { before: 60, after: 160 }, indent: { left: 360 }, keepNext: !!b.keepNext,
    border: { left: { style: BorderStyle.SINGLE, size: 12, color: ACCENT, space: 8 } },
    children: runs(b.note, { italics: true, color: '404040' }),
  })];
  if (b.bullets) return b.bullets.map((t) => {
    const [text, level] = Array.isArray(t) ? t : [t, 0];
    return new Paragraph({ numbering: { reference: 'bullets', level }, spacing: { after: 60 }, children: runs(text) });
  });
  if (b.steps) return b.steps.map((t) => new Paragraph({
    numbering: { reference: b.ref || 'steps', level: 0 }, spacing: { after: 60 }, children: runs(t),
  }));
  if (b.answer) {
    // A bordered box to write in (consecutive bordered paragraphs would merge into one line).
    const border = { style: BorderStyle.SINGLE, size: 4, color: 'A6A6A6' };
    return [
      new Paragraph({ spacing: { before: 120, after: 60 }, keepNext: true, children: runs(b.answer === true ? 'Your answer:' : b.answer, { bold: true, color: ACCENT }) }),
      new Table({
        width: { size: CONTENT_W, type: WidthType.DXA }, columnWidths: [CONTENT_W],
        rows: [new TableRow({ height: { value: b.tall ? 1800 : 900, rule: 'atLeast' }, cantSplit: true, children: [new TableCell({
          width: { size: CONTENT_W, type: WidthType.DXA },
          borders: { top: border, bottom: border, left: border, right: border },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          children: [new Paragraph({ children: [] })],
        })] })],
      }),
      new Paragraph({ spacing: { after: 160 }, children: [] }),
    ];
  }
  if (b.table) {
    const cols = b.widths || b.table[0].map(() => Math.floor(CONTENT_W / b.table[0].length));
    const border = { style: BorderStyle.SINGLE, size: 4, color: 'BFBFBF' };
    const borders = { top: border, bottom: border, left: border, right: border };
    return [new Table({
      width: { size: cols.reduce((a, c) => a + c, 0), type: WidthType.DXA },
      columnWidths: cols,
      rows: b.table.map((row, ri) => new TableRow({
        tableHeader: ri === 0,
        children: row.map((cell, ci) => new TableCell({
          width: { size: cols[ci], type: WidthType.DXA }, borders,
          shading: ri === 0 ? { type: ShadingType.CLEAR, color: 'auto', fill: 'DEEAF6' } : undefined,
          margins: { top: 60, bottom: 60, left: 100, right: 100 },
          // keep: true holds the whole table on one page (each row kept with the next).
          children: [new Paragraph({ keepNext: !!b.keep && ri < b.table.length - 1, children: runs(cell, ri === 0 ? { bold: true } : {}) })],
        })),
      })),
    }), new Paragraph({ spacing: { after: 120 }, children: [] })];
  }
  if (b.pageBreak) return [new Paragraph({ pageBreakBefore: true, children: [] })];
  throw new Error('unknown block ' + JSON.stringify(b));
}

async function build(file, { title, subtitle, blocks, footer }) {
  const doc = new Document({
    creator: 'South Plains Implement', title,
    styles: {
      default: { document: { run: { font: FONT, size: 22 } } },
      paragraphStyles: [
        { id: 'Title', name: 'Title', basedOn: 'Normal', run: { size: 40, bold: true, color: ACCENT, font: FONT }, paragraph: { spacing: { after: 80 } } },
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 30, bold: true, color: ACCENT, font: FONT }, paragraph: { spacing: { before: 360, after: 120 }, outlineLevel: 0, keepNext: true } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 25, bold: true, color: '2E2E2E', font: FONT }, paragraph: { spacing: { before: 280, after: 100 }, outlineLevel: 1, keepNext: true } },
        { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 22, bold: true, color: ACCENT, font: FONT }, paragraph: { spacing: { before: 200, after: 80 }, outlineLevel: 2, keepNext: true } },
      ],
    },
    numbering: { config: [
      { reference: 'bullets', levels: [0, 1].map((level) => ({ level, format: LevelFormat.BULLET, text: level ? '–' : '•', alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 360 + level * 360, hanging: 260 } } } })) },
      ...['steps', 'steps2', 'steps3', 'steps4', 'steps5', 'steps6', 'steps7', 'steps8'].map((reference) => ({ reference, levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 360, hanging: 300 } } } }] })),
    ] },
    sections: [{
      properties: { page: { size: { width: PAGE_W, height: 15840 }, margin: { top: 1080, bottom: 1080, left: MARGIN, right: MARGIN } } },
      footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [
        new TextRun({ text: (footer || title) + '   ·   Page ', size: 16, color: '808080' }),
        new TextRun({ children: [PageNumber.CURRENT], size: 16, color: '808080' }),
      ] })] }) },
      children: [
        new Paragraph({ style: 'Title', children: [new TextRun(title)] }),
        ...(subtitle ? [new Paragraph({ spacing: { after: 240 }, border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: ACCENT, space: 6 } },
          children: runs(subtitle, { color: '595959' }) })] : []),
        ...blocks.flatMap(block),
      ],
    }],
  });
  fs.writeFileSync(file, await Packer.toBuffer(doc));
  console.log('wrote', file);
}

module.exports = { build, CONTENT_W };
