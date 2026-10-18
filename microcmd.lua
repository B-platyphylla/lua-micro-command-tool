-- requires Lua 5.2+ 请使用lua5.2+
--lua micro command tool
--[[
加载；推荐使用require
local microcmd = require("microcmd")
请以":"调用函数   please use ":" instead of "." when call the function
  microcmd:splitStr(s) ✅，microcmd.splitStr(s) ❌

  microcmd:splitStr(str)                 str:command string → command table
  microcmd:findFunction(tab)             tab:command table → f, args, nil | nil, nil, err
  microcmd:resolveCmd(str)               str:command string →  = splitStr + findFunction）
  microcmd:runCmdWithPcall(tab)          tab:command table → pcall 结果(true,ret|false,err) | nil, err
  microcmd:readAndRunCommand(file)       file:file 对象或 nil(use stdin) → 同 runCmdWithPcall；每次读一行

请把命令和函数以command=function或command1={command2=function}的形式放入microcmd.commandFunctionTable

举例；microcmd.commandFunctionTable={ ls = fn, sub = { inner = fn2 } }
  命令 "sub inner a b" 会调用 fn2("a","b")。table 层级即命名空间。
  sub inner "a b" → fn2("a b")
  ls "a'b"   →   fn("a'b")
  ls a'b'c   →   fn("a'b'c")
  ls "12345" →   fn("12345")
  ls 12345   →   fn(12345)
  
  只识别十进制数字，请注意
  1.123✅  10000✅  1e15❌
  
  readAndRunCommand 的 file:read() 可能阻塞,多线程时注意。

  
findFunction / resolveCmd 失败fail → nil, nil, err（err 在第三位）
runCmdWithPcall           失败fail → nil, err（err 在第二位，与 pcall 风格对齐）
  
]]
local microcmd={}
--local function coerceTypes(sourcetable,j)--将表里相应的数字，布尔转换
--  local tab=table.pack(table.unpack(sourcetable,j))
--  local str
--  local theNB
--  for i = 1,#tab do
--    str=tab[i]
--    if type(str)=='string' then
--    theNB = tonumber(str)
--    else
--    theNB = nil
--    end
--    if str == 'true' then
--      tab[i]= true
--    elseif str == 'false' then
--      tab[i]= false
--    elseif theNB then
--      tab[i]= theNB
--    end
--  end
--  return tab
--end
function microcmd:splitStr(str)
  local result = {}--最后输出这个表
  local sbs
  local isic=false
  local l={}
  for i = 1 , #str do
    sbs = string.sub(str,i,i)
    if sbs:find("%s") and not isic then
      if #l>=1 then
        table.insert(result,table.concat(l))
      end
      l={}
    elseif (sbs==[[']] or sbs==[["]]) then
      if (not isic) and #l == 0 then
        isic = sbs
        table.insert(l,sbs)
      elseif isic == sbs then
        isic = false
        table.insert(l,sbs)
      else
        table.insert(l,sbs)
      end
    else
      table.insert(l,sbs)
    end
  end
  if #l >= 1 then table.insert(result, table.concat(l)) end
  --后处理
  for i=1,#result do
  if type(result[i])=="string" then
    --if string.find(result[i],[=[^%b["']["']$]=]) then
    --  result[i]=result[i].match([=[^["'](.)*["']$]=])
    local q = result[i]:sub(1, 1)
    if #result[i] >= 2 and (q == '"' or q == "'") and result[i]:sub(-1) == q then
      if #result[i] == 2 then
        result[i] = "" 
      else
        result[i] = result[i]:sub(2, -2)
      end
    
    elseif result[i]=="true" then
      result[i]=true
    elseif result[i]=="false" then
      result[i]=false
    elseif result[i]:find("^[+-]?%d+$") or result[i]:find("^[+-]?%d+%.%d+$") then
      result[i]=tonumber(result[i])
    end
  end
  end
  return result
end

      
    
--[==[function microcmd:splitStr(str)
  local result = {}--最后输出这个表
  local l
  local sbs
  local isic=false--当前引号状态，false表示不在引号内，否则存引号字符
  local isic2=false
  for i=1,#str do
    if not l then l="" end
    sbs = string.sub(str,i,i)
    if (sbs == [["]] or sbs == [[']]) then
      if isic == sbs then
        isic = false--如果有同种引号关闭引号
      elseif (not isic) and #l==0 then--开引号，仅token首字符
        isic = sbs
      end
    end
    
    if sbs:find([=[[%s]]=]) and not isic then--空白且不在引号内则切分
      if #l >=1 then
      table.insert(result,l)
      end
      l=nil
    elseif not ((sbs == [[']] or sbs ==[["]])and (#l==0 or isic2 ~= isic)) then--不拼入引号
      l=l..sbs
    end
    isic2 = isic
  end
  if l and #l>=1 then table.insert(result, l) end
  return result
end ]==]
microcmd.commandFunctionTable={}
function microcmd:findFunction (tab)--tab is table
  local value
  local f = self.commandFunctionTable
  if not f then 
    
    return nil,nil,'no function table'
  end
  for i=1,#tab do
    f=f[tab[i]]
    local typef = type(f)
    if typef == 'function' then
      value=table.pack(table.unpack(tab,i+1))--findFunction 不做类型转换
      return f,value,nil
    elseif typef ~= "table" then
      return nil,nil,"not a table or function"
    end
  end
  return nil,nil,'no function found'
end
function microcmd:runCmdWithPcall(source)
  local f,value,err=self:findFunction(source)
  if f then
    return pcall(f,table.unpack(value))
  end
  return nil,err
end
function microcmd:readAndRunCommand(file)--传入文件对象或者不传（你必须自己io.open）
  --每次只读一行，推荐用户自己写循环。read可能卡死线程，用户需要注意。
  file=file or io.stdin
  local input=file:read()
  if input and #input>=1 then
    local tab=self:splitStr(input)
    return self:runCmdWithPcall(tab)
  else
    return nil , 'no input'
  end
end
function microcmd:resolveCmd(input)--这里收string
  if type(input)=="string" and #input>=1 then
    local tab=self:splitStr(input)
    return self:findFunction(tab)
  else
    return nil,nil,"no input"
  end
end
return microcmd