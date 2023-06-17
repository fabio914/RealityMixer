## Additional Instructions

Mixed Reality Capture is broken on the Quest 2/Pro after version 51 was released. You'll need to use Developer mode and [SideQuest](https://sidequestvr.com/setup-howto) to be able to copy the calibration file (`mrc.xml`) manually to the right place. This tutorial is assuming that you already have SideQuest and Developer mode setup correctly (follow [these instructions](https://sidequestvr.com/setup-howto) first if that's not the case).

1. After completing the calibration, do not move your iPhone/iPad. Connect your Quest 2/Pro to your PC and follow the next steps.

2. Open SideQuest, authorize the connection in the headset, and click on the folder icon on the top right ("File Manager").

<img src="Images/additional-instructions/1.png" width="300" />

<img src="Images/additional-instructions/2.png" width="300" />

3. Navigate to `/sdcard/Android/data/com.oculus.MrcCameraCalibration/files` and copy the `mrc.xml` file to your computer (after completing the calibration).

<img src="Images/additional-instructions/3.png" width="300" />

<img src="Images/additional-instructions/4.png" width="300" />

4. Navigate to the `files` directory of the game you want to record and paste the `mrc.xml` file there.

For example, paste the `mrc.xml` file inside `/sdcard/Android/data/com.beatgames.beatsaber/files` for Beat Saber.

5. Disconnect the headset from your PC. Launch the game you want to record, and then start the Mixed Reality connection on Reality Mixer.

**Unfortunately, you'll need to repeat these steps every time you change the callibration (i.e. every time you move your iPhone/iPad), and you'll need to copy this `mrc.xml` file to every game/app you want to record.**
