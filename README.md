<img src="Images/rounded.png" width="100" />

# Reality Mixer <br/> *Oculus Quest Mixed Reality For iOS*

This is a standalone Oculus Quest Mixed Reality app for iOS. It is able to generate VR gameplay videos in Mixed Reality without a PC and without a green screen.

Follow us on [Twitter](https://twitter.com/reality_mixer) for more updates!

## Examples

| Game | YouTube video | Photos |
|------|---------------|--------|
| Beat Saber | [Link](https://www.youtube.com/watch?v=JL5e_moZ7XM) | <img src="Images/beatsaber/1.jpg" width="300" /> <img src="Images/beatsaber/2.jpg" width="300" /> |
| SUPERHOT | [Link](https://youtu.be/ZnOY8juMw4k) | <img src="Images/superhot/1.jpg" width="300" /> <img src="Images/superhot/2.jpg" width="300" /> |
| The Thrill of the Fight | [Link](https://youtu.be/aPSBmej4ppc) | <img src="Images/the_thrill_of_the_fight/1.jpg" width="300" /> <img src="Images/the_thrill_of_the_fight/2.jpg" width="300" /> |
| Space Pirate Trainer | [Link](https://youtu.be/44Nmv7Es5yI) | <img src="Images/space_pirate_trainer/1.jpg" width="300" /> <img src="Images/space_pirate_trainer/2.jpg" width="300" /> |

## Requirements

 - Oculus Quest 1 or 2 with the [Oculus MRC Calibration app](https://www.oculus.com/experiences/quest/2532132800176262/) version 1.7 installed.
 - iPhone or iPad with an A12 chip or newer, running iOS 14. The LiDAR sensor is optional but recommended for better results.
 - 5 Ghz WiFi network.
 - A compatible Quest VR application/game (check this [page](https://creator.oculus.com/mrc/) for a list of the officially supported games).

Note that this app is still just a prototype and it's still being developed, use at your own risk.

## Installation

### AltStore

 - Follow [these instructions](https://altstore.io/) to install and configure AltServer on your PC or Mac, then install the AltStore app on your iPhone/iPad.
 
 - Open the camera app on your iPhone/iPad and scan this QR code:

![download](https://user-images.githubusercontent.com/2430631/98993411-52055c00-2526-11eb-9c38-f5a4e075ecc7.png)

OR

- Open this URL on your iPhone/iPad:

```
altstore://install?url=https://github.com/fabio914/OculusQuestMixedRealityForiOS/releases/download/0.1.2/RealityMixer.ipa
```

### Test Flight

*Coming soon?*

## Instructions

[Link](Instructions.md)

## Credits

This project is based on the [Oculus MRC plugin for OBS](https://github.com/facebookincubator/obs-plugins/tree/master/oculus-mrc).

It uses [SwiftSocket](https://github.com/swiftsocket/SwiftSocket) to handle the TCP connection with the Oculus Quest, FFMPEG with Apple's VideoToolbox to decode the stream, and ARKit for the "virtual green screen". 

The right and left controller models are modified versions of the `oculus-touch-v3` models from the [WebXR Input Profiles](https://github.com/immersive-web/webxr-input-profiles).

It also requires [Carthage](https://github.com/Carthage/Carthage) to download its dependencies.

## Contributors

[Fabio de A. Dela Antonio](https://github.com/fabio914/)

[Giovanni Longatto N. Marques](https://github.com/gmarques33)

## TO-DOs

 - Optimize the video stream;
