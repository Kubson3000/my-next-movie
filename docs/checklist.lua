-- A task list (- [ ] item) gets a box instead of the bullet, not both.

local box = "\u{2610}"  -- the ballot box pandoc puts in a task list item

local function starts_with_box(item)
  local first = item[1]
  return first and (first.t == "Plain" or first.t == "Para")
    and first.content[1] and first.content[1].t == "Str"
    and first.content[1].text == box
end

function BulletList(list)
  for _, item in ipairs(list.content) do
    if not starts_with_box(item) then
      return nil
    end
  end
  for _, item in ipairs(list.content) do
    local inlines = item[1].content
    inlines:remove(1)
    if inlines[1] and inlines[1].t == "Space" then
      inlines:remove(1)
    end
  end
  return {
    pandoc.RawBlock("typst", "#[#set list(marker: [" .. box .. "])"),
    list,
    pandoc.RawBlock("typst", "]"),
  }
end
