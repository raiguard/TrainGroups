[![shield](https://img.shields.io/badge/Ko--fi-Donate%20-hotpink?logo=kofi&logoColor=white)](https://ko-fi.com/raiguard)
[![shield](https://img.shields.io/badge/Crowdin-Translate-brightgreen)](https://crowdin.com/project/raiguards-factorio-mods)
[![shield](https://img.shields.io/badge/dynamic/json?color=orange&label=Factorio&query=downloads_count&suffix=%20downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2FTrainGroups)](https://mods.factorio.com/mod/TrainGroups)

# Train Groups

Train Groups is a Factorio mod enabling you to sync the schedules of multiple trains.

## Download

Download on the [Factorio mod portal](https://mods.factorio.com/mod/TrainGroups).

## Features

The mod adds a new button to the top of the train GUI.

![](screenshots/no-group.png)

Clicking this button allows you to select or create a train group.

![](screenshots/change-group.png)

Changing to a group will sync the train's schedule to the other trains in that group.

![](screenshots/other-group.png)

Any changes made to a schedule will be immediately reflected in the schedules of all trains in the group. Temporary stations will be ignored.

The mod also adds a widget to the train overview GUI that lists your groups, and allows you to rename or delete them.

![](screenshots/overview.png)

If you have no groups, the mod will offer to auto-create them based on train schedule.

## Compatibility

In general, any changes made to schedules by mods will be ignored; only edits made by players will be synced. The following mods have extra compatibility:

### Train Control Signals

The skip signal from [Train Control Signals](https://mods.factorio.com/mod/Train_Control_Signals) will be filtered out when syncing schedules. This causes it to temporarily disappear from the other trains when the schedule is edited, but does not affect the functionality of TCS.

### Train Schedule Signals

All wait conditions on stations utilizing [Train Schedule Signals](https://mods.factorio.com/mod/TrainScheduleSignals) will be ignored, as those are managed directly by TSS.
