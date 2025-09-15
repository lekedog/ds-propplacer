-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function versionCheckPrint(_type, log)
    local color = _type == 'success' and '^2' or '^1'
    print(('^5[ds-propplacer]%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/lekedog/ds-versioncheckers/main/ds-propplacer/version.txt', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        -- current version matched
        if text == currentVersion then 
            versionCheckPrint('success', 'You are running the latest version: '..currentVersion)
            return
        end

        -- not able to check version
        if not text then
            versionCheckPrint('error', 'Currently unable to run a version check.')
            return
        end

        -- current version did not match
        if text ~= currentVersion then
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()