-- @description Reaper LTC Markers - Edit Mapping
-- @version 0.3.0
-- @author Reaper LTC Markers
-- @about
--   CSV mapping editor using stock REAPER gfx (no ReaImGui required).
-- @provides
--   [main] Reaper LTC Markers - Edit Mapping.lua
--   [nomain] modules/*.lua

local SCRIPT_PATH = ({reaper.get_action_context()})[2]
local SCRIPT_DIR = SCRIPT_PATH:match("^(.*[\\/])") or ""
package.path = SCRIPT_DIR .. "modules/?.lua;" .. package.path

require("rlm_mapping_editor").open()
