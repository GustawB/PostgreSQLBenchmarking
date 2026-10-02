-- Pandoc filter for the two-column PDF build.
-- * "**Table N.** caption" paragraph + following table -> booktabs tabular float
--   (table* spanning both columns if it has more than 3 columns).
-- * Paragraph made only of images + following "**Figure N.** caption" paragraph
--   -> figure* with the images side by side.
-- * Single-image figure -> column-width figure.
-- * Citation numbers like [4] or [6, 7] -> links to the reference entries.
-- * Multi-line author list -> single author block separated by line breaks.

local function latex(inlines)
  return (pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), 'latex'):gsub('%s+$', ''))
end

-- Returns caption inlines if the paragraph starts with **<label> N.**, else nil.
local function caption_of(block, label)
  if not block or block.t ~= 'Para' then return nil end
  local first = block.content[1]
  if not first or first.t ~= 'Strong' then return nil end
  if not pandoc.utils.stringify(first):match('^' .. label .. ' %d+%.$') then return nil end
  local rest = pandoc.List()
  for i = 2, #block.content do rest:insert(block.content[i]) end
  while rest[1] and rest[1].t == 'Space' do rest:remove(1) end
  return rest
end

local function only_images(block)
  if block.t ~= 'Para' then return nil end
  local imgs = {}
  for _, el in ipairs(block.content) do
    if el.t == 'Image' then table.insert(imgs, el)
    elseif el.t ~= 'Space' and el.t ~= 'SoftBreak' then return nil end
  end
  return #imgs > 1 and imgs or nil
end

local function cell_text(cell)
  return latex(pandoc.utils.blocks_to_inlines(cell.contents))
end

local function render_table(tbl, caption)
  local ncols = #tbl.colspecs
  local wide = ncols > 3
  local env = wide and 'table*' or 'table'
  local spec = {}
  for i, cs in ipairs(tbl.colspecs) do
    local align = cs[1]
    if not wide and i == 1 then spec[i] = 'p{0.55\\linewidth}'
    elseif align == 'AlignRight' then spec[i] = 'r'
    elseif align == 'AlignCenter' then spec[i] = 'c'
    else spec[i] = 'l' end
  end
  local out = { '\\begin{' .. env .. '}[t]', '\\centering\\small',
    '\\caption{' .. latex(caption) .. '}', '\\begin{tabular}{' .. table.concat(spec) .. '}',
    '\\toprule' }
  local function row(r)
    local cells = {}
    for _, c in ipairs(r.cells) do table.insert(cells, cell_text(c)) end
    return table.concat(cells, ' & ') .. ' \\\\'
  end
  for _, r in ipairs(tbl.head.rows) do table.insert(out, row(r)) end
  table.insert(out, '\\midrule')
  for _, body in ipairs(tbl.bodies) do
    for _, r in ipairs(body.body) do table.insert(out, row(r)) end
  end
  table.insert(out, '\\bottomrule')
  table.insert(out, '\\end{tabular}')
  table.insert(out, '\\end{' .. env .. '}')
  return pandoc.RawBlock('latex', table.concat(out, '\n'))
end

local function render_figure(imgs, caption)
  local width = string.format('%.2f', 0.98 / #imgs)
  local parts = {}
  for _, img in ipairs(imgs) do
    table.insert(parts, '\\includegraphics[width=' .. width .. '\\textwidth]{' .. img.src .. '}')
  end
  return pandoc.RawBlock('latex', table.concat({
    '\\begin{figure*}[t]', '\\centering', table.concat(parts, '\\hfill\n'),
    '\\caption{' .. latex(caption) .. '}', '\\end{figure*}' }, '\n'))
end

-- Turns "[4]" / "[6," "7]" citation tokens into links to the matching reference.
local function link_citations(inlines)
  local out, open = pandoc.List(), false
  for _, el in ipairs(inlines) do
    local bracket, num, rest
    if el.t == 'Str' then
      bracket, num, rest = el.text:match('^(%[)(%d+)([,%]].*)$')
      if not bracket and open then num, rest = el.text:match('^(%d+)([,%]].*)$') end
    end
    if num then
      if bracket then out:insert(pandoc.Str('[')) end
      out:insert(pandoc.Link({ pandoc.Str(num) }, '#ref-' .. num))
      out:insert(pandoc.Str(rest))
      open = rest:sub(1, 1) == ','
    else
      out:insert(el)
      if el.t ~= 'Space' then open = false end
    end
  end
  return out
end

-- Anchors "[n] ..." reference entries and links citations everywhere before them.
local function add_citation_links(blocks)
  local in_refs = false
  for i, b in ipairs(blocks) do
    if b.t == 'Header' then
      in_refs = pandoc.utils.stringify(b) == 'References'
    elseif in_refs and b.t == 'Para' then
      local num = b.content[1] and b.content[1].t == 'Str' and b.content[1].text:match('^%[(%d+)%]$')
      if num then b.content[1] = pandoc.Span({ b.content[1] }, { id = 'ref-' .. num }) end
    else
      blocks[i] = b:walk({ Inlines = link_citations })
    end
  end
end

function Pandoc(doc)
  add_citation_links(doc.blocks)
  local blocks, out, i = doc.blocks, pandoc.List(), 1
  while i <= #blocks do
    local b, nxt = blocks[i], blocks[i + 1]
    local tcap = caption_of(b, 'Table')
    local imgs = only_images(b)
    if b.t == 'Figure' then
      -- Single image with its own caption: fit it to the column, not the page.
      local img
      b:walk({ Image = function(el) img = el end })
      local cap = pandoc.utils.blocks_to_inlines(b.caption.long)
      out:insert(pandoc.RawBlock('latex', table.concat({ '\\begin{figure}[t]', '\\centering',
        '\\includegraphics[width=\\columnwidth]{' .. img.src .. '}',
        '\\caption{' .. latex(cap) .. '}', '\\end{figure}' }, '\n')))
      i = i + 1
    elseif tcap and nxt and nxt.t == 'Table' then
      out:insert(render_table(nxt, tcap)); i = i + 2
    elseif imgs and caption_of(nxt, 'Figure') then
      out:insert(render_figure(imgs, caption_of(nxt, 'Figure'))); i = i + 2
    else
      out:insert(b); i = i + 1
    end
  end
  doc.blocks = out

  local authors = doc.meta.author
  if authors and authors.t == 'MetaList' then
    local lines = {}
    for _, a in ipairs(authors) do table.insert(lines, latex(pandoc.utils.stringify(a))) end
    doc.meta.author = pandoc.MetaInlines({ pandoc.RawInline('latex',
      lines[1] .. '\\\\[0.4em]\\small ' .. table.concat(lines, '\\\\', 2)) })
  end
  return doc
end
