## Additional Instructions

Mixed Reality Capture is broken on the Quest 2/Pro after version 51 was released. You'll need to use Developer mode and [SideQuest](https://sidequestvr.com/setup-howto) to be able to copy the calibration file (`mrc.xml`) manually to the right place. This tutorial is assuming that you already have SideQuest and Developer mode setup correctly (follow [these instructions](https://sidequestvr.com/setup-howto) first if that's not the case).

1. Connect your Quest 2/Pro to your PC and follow the next steps.

2. Open SideQuest, authorize the connection in the headset, and click on the folder icon on the top right ("File Manager").

<img src="Images/additional-instructions/1.png" width="300" />

<img src="Images/additional-instructions/2.png" width="300" />

3. Navigate to `/sdcard/Android/data/com.oculus.MrcCameraCalibration/files` and copy the `mrc.xml` file to your computer.

<img src="Images/additional-instructions/3.png" width="300" />

<img src="Images/additional-instructions/4.png" width="300" />

If that file doesn't exist, copy the content below and paste it into a text file and then save it as `mrc.xml`:

```xml
<?xml version="1.0"?>
<opencv_storage>
    <camera_id>1</camera_id>
    <camera_name>Reality Mixer Camera</camera_name>
    <image_width>960</image_width>
    <image_height>720</image_height>
    <camera_matrix type_id="opencv-matrix">
        <rows>3</rows>
        <cols>3</cols>
        <dt>d</dt>
        <data>7.94199039034754e+2 0e+0 4.8e+2 0e+0 7.94199039034754e+2 3.6e+2 0e+0 0e+0 1e+0</data>
    </camera_matrix>
    <distortion_coefficients type_id="opencv-matrix">
        <rows>8</rows>
        <cols>1</cols>
        <dt>d</dt>
        <data>0. 0. 0. 0. 0. 0. 0. 0.</data>
    </distortion_coefficients>
    <translation type_id="opencv-matrix">
        <rows>3</rows>
        <cols>1</cols>
        <dt>d</dt>
        <data>1.564499e+0 1.639794e+0 7.870319e-1</data>
    </translation>
    <rotation type_id="opencv-matrix">
        <rows>4</rows>
        <cols>1</cols>
        <dt>d</dt>
        <data>-2.55575679409995e-2 3.4795698448984e-1 3.11432380390578e-2 9.36644465767678e-1</data>
    </rotation>
    <attachedDevice>3</attachedDevice>
    <camDelayMs>0</camDelayMs>
    <chromaKeyColorRed>0</chromaKeyColorRed>
    <chromaKeyColorGreen>255</chromaKeyColorGreen>
    <chromaKeyColorBlue>0</chromaKeyColorBlue>
    <chromaKeySimilarity>6.0000002384185791e-01</chromaKeySimilarity>
    <chromaKeySmoothRange>2.9999999329447746e-02</chromaKeySmoothRange>
    <chromaKeySpillRange>5.9999998658895493e-02</chromaKeySpillRange>
    <raw_translation type_id="opencv-matrix">
        <rows>3</rows>
        <cols>1</cols>
        <dt>d</dt>
        <data>3.875585e-1 1.04385e+0 4.608449e-1</data>
    </raw_translation>
    <raw_rotation type_id="opencv-matrix">
        <rows>4</rows>
        <cols>1</cols>
        <dt>d</dt>
        <data>0e+0 9.969339e-1 0e+0 7.824831e-2</data>
    </raw_rotation>
</opencv_storage>
```

This file is assuming a resolution of 960x720. If this aspect ratio does not match that of your device's camera, then the image will be off. Ideally, you would need to know the resolution and aspect ration of your device and adjust `image_width`, `image_height`, and `camera_matrix`. 

4. Navigate to the `files` directory of the game you want to record and paste the `mrc.xml` file there.

For example, paste the `mrc.xml` file inside `/sdcard/Android/data/com.beatgames.beatsaber/files` for Beat Saber.

5. Disconnect the headset from your PC. 

6. Complete a new calibration with Reality Mixer, then launch the game you want to record, and enable the "Enable Moving Camera" option before you start the mixed reality connection. Make sure that you haven't moved your iPhone/iPad after you completed the calibration and before you started the mixed reality connection.

### Why is this broken?

The Mixed Reality Calibration app on the Quest receives a calibration file from the Reality Mixer app and copies it to every other app in your Quest 2/Pro. This process is no longer working due to some permission changes with newer Android versions.

Apps that support Mixed Reality Capture will only accept a Mixed Reality Connection if they have a valid `mrc.xml` file in their folder. 

If that's an old `mrc.xml` that no longer corresponds to the position of your iPhone/iPad then the calibration will be off. 

You can use the "Enable Moving Camera" option when starting a new Mixed Reality Connection to avoid copying a new `mrc.xml` file every time (even if you decide not to move the camera). This method updates the calibration on the fly (so it doesn't matter that the calibration inside the `mrc.xml` file isn't up to date, as long as the game/app can read this file). 

Notice that this method still requires completing a new calibration before starting the Mixed Reality connection, and you shouldn't move your device after calibrating and before starting the connection, or between mixed reality sessions.
