# Data Import Guide
This guide explains how to import PvP statistics from a different World of Warcraft installation. This guide assumes you want to import from Classic Anniversary to TBC Anniversary.

## Prerequisites
Ensure all WoW clients are closed before editing any files.

## Step 1: Backup
Before proceeding, locate your TBC Client's `SavedVariables` folder and create a backup of your `PvPStatsClassic.lua`. Open Battle.net launcher and click *Show in Explorer* for TBC Anniversary:

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/0_show_tbc_anniversary_in_explorer.jpg" alt="Source Installation" width="700">

Navigate to `WTF\Account\<your account>\SavedVariables` and create a backup of your `PvPStatsClassic.lua`file:

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/0_1_backup_pvp_stats_classic_lua.jpg" alt="Backup" width="700">

Leave this explorer window open, you will need it later!

## Step 2: Locate Classic Era Installation folder
Open Battle.net launcher and click *Show in Explorer* for Classic Era (Anniversary does not exist anymore because it was moved to TBC, but it's the same client):

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/1_show_classic_client_in_explorer.jpg" alt="Classic Client" width="700">

## Step 3: Find the Classic Era `PvPStatsClassic.lua` file
Navigate to `WTF\Account\<your account>\SavedVariables` and select the file `PvPStatsCLassic.lua`

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/3_find_PvPStatsClassic_lua_in_the_saved_variables_folder.jpg" alt="Find File" width="800">

Open this file with a text editor (like Notepad).

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/4_open_with_notepad.jpg" alt="Open File" width="600">

## Step 4: Prepare Data for Import
In the opened file, find the line that starts with `PSC_DB = {`.
**Rename** `PSC_DB` to `PSC_DB_IMPORT`.

*This is critical to ensures the addon recognizes this as data to be imported!*

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/5_add_IMPORT_to_PSC_DB.jpg" alt="Rename DB" width="500">

## Step 5: Copy Data
Select **everything** in the file (Ctrl+A) and copy it (Ctrl+C or right-click -> copy).

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/6_select_everything_and_copy.jpg" alt="Copy Data" width="600">

Don't save the changes to this file!

## Step 6: Open TBC Anniversary `PvPStatsClassic.lua` file
Go back to the TBC Anniversary `SavedVariables` folder (where you created the backup in Step 1) and open the file `PvPStatsClassic.lua` in Notepad:

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/7_open_tbc_pvp_stats_classic_lua_in_notepad.jpg" alt="Open Target" width="800">

## Step 7: Paste Import Data
Paste the copied content at the very **beginning** of the file (before the existing `PSC_DB` block).

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/8_paste_copied_content_from_classic_lua_to_first_line_of_tbc_lua.jpg" alt="Paste Data" width="800">

## Step 8: Save and Close
Save the changes to the TBC Anniversary file and close it.

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/9_save_the_file_in_notepad.jpg" alt="Save File" width="600">

Close the Classic Era file **without** saving:

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/10_close_both_files_and_discard_the_changes_to_classic_lua_file.jpg" alt="Close Files" width="900">

## Step 9: Launch Game
Start TBC Anniversary.

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/11_start_tbc_anniversary.jpg" alt="Start Game" width="800">

## Step 10: Confirm Import
Log in to your character. After a short moment, you should see a popup window detecting the imported data.
Verify that the numbers (Kills and achievements) look plausible.
Click **Yes** to merge the data.

<img src="https://github.com/randomdude163/WoWClassic_PvPStats/blob/main/PvPStatsClassic/img/Screenshots/data_import/12_login_wait_for_the_popup_make_sure_the_data_is_plausible_and_click_yes.jpg" alt="Confirm Import" width="400">


## Step 11: Verify merged data
Open the statistics window (left click on the minimap button or type */psc statistics* in the chat) and look at all the numbers and charts. Do they look plausible? If yes, you are done. If no, close the game, delete the `PvPStatsClassic.lua` file in the TBC Anniversary `SavedVariables` folder, copy your backup file and name it `PvPStatsClassic.lua`, then start again from Step 1.

If after a second try you still encounter issues, join the *\<Redridge Police\>* Discord at https://discord.gg/ZBaN2xk5h3 and ask Severussnipe for help.
