local Config = {}
-- Option One - change to your framework's player group or role system ---------------------------OPTION ONE----------------------------------
-- ONLY GOD or ADMIN can place/remove props --------------------------------------------------RECOMMENDED-CHOICE------------------------------
-- In your database, set your player group to 'god' or 'admin'
-- Here is the SQL to do that:
-- -----------------------------------------------------------------------Quary SQL:
-- -----------------------------------------------------------copy-paste>  ALTER TABLE players ADD COLUMN `group` VARCHAR(20) DEFAULT 'user';
-- If you already have that Column, you can skip the above line
-- Then you will need to UPDATE your player to 'god' or 'admin'
-- -----------------------------------------------------------------------Quary SQL:
-- ------------------------------------------------if ADMIN > copy-paste> UPDATE players SET `group` = 'admin' WHERE citizenid = 'THERE CitizenID GOES HERE';
-----------------------------------------------------if GOD > copy-paste> UPDATE players SET `group` = 'god' WHERE citizenid = 'THERE CitizenID GOES HERE';




----------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------DONT DO BOTH---------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------





-- Option Two - Server owner CitizenID (replace with your real CitizenID)-------------------------OPTION TWO----------------------------------
Config.ServerOwnerCitizenId = "########" --------------------------------------------- IGNORE THIS LINE IF USING OPTION ONE

-- Add additional config variables below as needed

return Config