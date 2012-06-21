--[[
IPSet-based masquerading module for Alpine Wall
Copyright (C) 2012 Kaarle Ritvanen
Licensed under the terms of GPL2
]]--


module(..., package.seeall)

classes = {}

-- TODO configuration of the ipset via JSON config
defrules = {pre={{family='inet', table='nat', chain='POSTROUTING',
		  opts='-m set --match-set awall-masquerade src -j awall-masquerade'},
		 {family='inet', table='nat', chain='awall-masquerade',
		  opts='-m set ! --match-set awall-masquerade dst -j MASQUERADE'}}}
