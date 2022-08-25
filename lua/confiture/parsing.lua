local parsing = {}

-- tokenizer state machine, which for each state/type of token:
-- * should_continue:
--      return true if the new character should be added to token string,
--      false if not and should switch to another state
-- * nex_state_decide:
--      return which new state/token type to switch to given the current
--      character (called separator as it signifies the end of a token)
-- * make_token:
--      convert a token string to an actual token
local states = {}

states.word = {
  should_continue = function(_, char)
    return char:match('[%w_@]')
  end,

  nex_state_decide = function(sep)
    if sep:match("%s") then
      return "out"
    elseif sep == ':' then
      return "separator"
    elseif sep == '"' then
      return "script_str"
    elseif sep == '#' then
      return "comment"
    end
  end,

  make_token = function(token_str)
    local first_char = string.sub(token_str, 1, 1)
    local rest_of_string = string.sub(token_str, 2, #token_str)

    -- '@' is only possible at beginning of word
    if rest_of_string:match('@') then return nil end

    if first_char == '@' then
      return {
        type = "command",
        value = rest_of_string
      }
    else
      if token_str == "true" then
        return {
          type = "boolean",
          value = true
        }
      elseif token_str == "false" then
        return {
          type = "boolean",
          value = false
        }
      else
        return {
          type = "variable",
          value = token_str
        }
      end
    end
  end
}

states.separator = {
  should_continue = function(token, _)
    return #token == 0
  end,

  nex_state_decide = function(sep)
    if sep:match("%s") then
      return "out"
    elseif sep == '"' then
      return "script_str"
    elseif sep == '#' then
      return "comment"
    end
  end,

  make_token = function(_)
    return {
      type = "separator",
      value = ':'
    }
  end
}

states.script_str = {
  should_continue = function(token, _)
    local last_two_chars = string.sub(token, #token - 1, #token)

    return not last_two_chars:match('[^\\]"')
  end,

  nex_state_decide = function(sep)
    if sep:match("%s") then
      return "out"
    end
  end,

  make_token = function(token_str)
    if token_str:sub(1, 1) ~= '"' or token_str:sub(#token_str, #token_str) ~= '"' then
      -- a script_str should begin and end with a '"'
      return nil
    end

    return {
      type = "script_str",
      value = token_str:sub(2, #token_str - 1)
    }
  end
}

states.out = {
  should_continue = function(_, char)
    return char:match('%s')
  end,

  nex_state_decide = function(sep)
    if sep:match('[@%w_]') then
      return "word"
    elseif sep == ':' then
      return "separator"
    elseif sep == '"' then
      return "script_str"
    elseif sep == '#' then
      return "comment"
    end
  end
}

states.comment = {
  should_continue = function(_, _)
    return true
  end
}

-- if a string is returned, it is an error message
function parsing.tokenize(str)
  local tokens = {}
  local cur_token = ''
  local i = 1
  local c = str:sub(1, 1)
  local cur_state = "out"

  while true do
    if c ~= "" and states[cur_state].should_continue(cur_token, c) then
      cur_token = cur_token .. c
      i = i + 1
      c = str:sub(i, i)
    else
      -- c is a separator
      if cur_state ~= "out" and cur_state ~= "comment" then
        local parsed_token = states[cur_state].make_token(cur_token)

        if parsed_token == nil then
          return "error with token '" .. cur_token .. "'"
        end

        table.insert(tokens, parsed_token)
      end

      if c == "" then break end -- reached end of str

      cur_token = ""
      cur_state = states[cur_state].nex_state_decide(c)

      if not cur_state then
        return "generic error with character '" .. c .. "' on column " .. i
      end
    end
  end

  return tokens
end

return parsing
