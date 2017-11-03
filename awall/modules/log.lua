--[[
Packet logging module for Alpine Wall
Copyright (C) 2012-2017 Kaarle Ritvanen
See LICENSE file for license details
]]--


local model = require('awall.model')
local class = model.class

local combinations = require('awall.optfrag').combinations
local util = require('awall.util')


local LogLimit = class(model.Limit)

function LogLimit:init(...)
   util.setdefault(self, 'src-mask', false)
   LogLimit.super(self):init(...)
end


local Log = class(model.ConfigObject)

function Log:matchofrags()
   local selector, ofrags

   for i, sel in ipairs{'every', 'limit', 'probability'} do
      local value = self[sel]
      if value then
	 if selector then
	    self:error('Cannot combine '..sel..' with '..selector)
	 end
	 selector = sel

	 if sel == 'every' then
	    ofrags = {
	       {match='-m statistic --mode nth --every '..value..' --packet 0'}
	    }
	 elseif sel == 'limit' then
	    ofrags = self:create(LogLimit, value, 'loglimit'):limitofrags()
	 elseif sel == 'probability' then
	    ofrags = {{match='-m statistic --mode random --probability '..value}}
	 else assert(false) end
      end
   end

   if self.mode == 'ulog' then
      ofrags = combinations({{family='inet'}}, ofrags)
   end

   return ofrags
end

function Log:target()
   local optmap = {
      log={level='level', prefix='prefix'},
      nflog={
	 group='group',
	 prefix='prefix',
	 range='range',
	 threshold='threshold'
      },
      ulog={
	 group='nlgroup',
	 prefix='prefix',
	 range='cprange',
	 threshold='qthreshold'
      }
   }

   local mode = self.mode or 'log'
   if mode == 'none' then return end
   if not optmap[mode] then self:error('Invalid logging mode: '..mode) end

   local res = mode:upper()
   for s, t in pairs(optmap[mode]) do
      local value = self[s]
      if value then
	 if s == 'prefix' then value = util.quote(value) end
	 res = res..' --'..mode..'-'..t..' '..value
      end
   end
   return res
end

function Log:optfrags()
   local target = self:target()
   return combinations(self:matchofrags(), {target and {target=target}})
end

function Log.get(rule, spec, default)
   if spec == nil then spec = default end
   if spec == false then return end
   if spec == true then spec = '_default' end
   return rule.root.log[spec] or rule:error('Invalid log: '..spec)
end


local LogRule = class(model.Rule)

function LogRule:init(...)
   LogRule.super(self):init(...)
   self.log = Log.get(self, self.log, true)
end

function LogRule:position() return 'prepend' end

function LogRule:mangleoptfrags(ofrags)
   return combinations(ofrags, self.log:matchofrags())
end

function LogRule:target() return self.log:target() end


return {
   export={
      log={class=Log}, ['packet-log']={class=LogRule, after='%filter-after'}
   }
}
