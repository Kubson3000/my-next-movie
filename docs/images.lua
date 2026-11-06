-- A paragraph with only an image, like ![Opis](diagrams/lab6-cinemas.svg),
-- becomes a centered diagram in its own size. The path is relative to docs/,
-- as on GitHub; Typst gets it from the repository root (--root .).

local function typst_string(text)
  return '"' .. text:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

function Para(para)
  if #para.content ~= 1 or para.content[1].t ~= "Image" then
    return nil
  end
  local image = para.content[1]
  local path = "/docs/" .. image.src
  local alt = pandoc.utils.stringify(image.caption)
  return pandoc.RawBlock("typst",
    "#block(width: 100%, breakable: false, above: 1.4em, below: 1.4em, "
    .. "align(center, image(" .. typst_string(path) .. ", alt: "
    .. typst_string(alt) .. ")))")
end
