# Reality Mixer For iOS

## Oculus Quest Mixed Reality For iOS

This is a standalone Oculus Quest Mixed Reality app for iOS that doesn't require a PC for generating Mixed Reality content.

This project is based on the [Oculus MRC plugin for OBS](https://github.com/facebookincubator/obs-plugins/tree/master/oculus-mrc), it uses [SwiftSocket](https://github.com/swiftsocket/SwiftSocket) to handle the TCP connection with the Oculus Quest, FFMPEG ~with Apple's VideoToolbox~ to decode the stream, and ARKit for the "virtual green screen". It also requires [Carthage](https://github.com/Carthage/Carthage).

This is still a work in progress and it has only been tested on the Oculus Quest 2 with Beat Saber. 

[YouTube video](https://www.youtube.com/watch?v=JL5e_moZ7XM)

![1](Images/Screenshots/1.jpg)

![2](Images/Screenshots/2.jpg)

## TO-DOs

- [ ] Add the foreground image;

- [ ] Implement the calibration mechanism;

- [ ] Optimize the video decoding with VideoToolbox (hardware decoding);

- [ ] Add audio (if possible);

- [ ] UI;
