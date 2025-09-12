# ds-propplacer
A Prop Placer for RSG Core (RedM)
This script allows Server Owners to place and delete props in-game using RSG Core permissions and notifications.

## 1. Installation
- Requires [RSG Core](https://github.com/RSG-Framework/rsg-core) installed and running.
- Clone `ds-propplacer` into your resources folder.
- Add the SQL provided to your Database.
- In the sv_main.lua make the necessary change to the OWNER CID
- Add `ensure ds-propplacer` to your `server.cfg` after `ensure rsg-core`.
- Restart Server

## 2. Usage
- `/placeprop [type] [model]` — Place a prop (example: `/placeprop test p_cratetnt02x`)
- `/removeprop [ID]` — Delete the placed prop
- `/listprops` — to list prop IDs in the F8 console

To find prop name's go to [Prop Lookup](https://redlookup.com/)

**Note:** Only the OWNER can place or delete props. (changes in the future)
