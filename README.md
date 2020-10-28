<img src="Images/rounded.png" width="100" />

# Reality Mixer <br/> *Oculus Quest Mixed Reality For iOS*

This is a standalone Oculus Quest Mixed Reality app for iOS that doesn't require a PC for generating Mixed Reality content.

This project is based on the [Oculus MRC plugin for OBS](https://github.com/facebookincubator/obs-plugins/tree/master/oculus-mrc), it uses [SwiftSocket](https://github.com/swiftsocket/SwiftSocket) to handle the TCP connection with the Oculus Quest, FFMPEG with Apple's VideoToolbox to decode the stream, and ARKit for the "virtual green screen". It also requires [Carthage](https://github.com/Carthage/Carthage).

This is app is still a prototype and it requires an iPhone/iPad with an A12 chip or newer. A device with LiDAR is recommended for better results.

## Examples

| Game | YouTube video | Photos |
|------|---------------|--------|
| Beat Saber | [Link](https://www.youtube.com/watch?v=JL5e_moZ7XM) | <img src="Images/beatsaber/1.jpg" width="300" /> <img src="Images/beatsaber/2.jpg" width="300" /> |
| SUPERHOT | [Link](https://youtu.be/ZnOY8juMw4k) | <img src="Images/superhot/1.jpg" width="300" /> <img src="Images/superhot/2.jpg" width="300" /> |
| The Thrill of the Fight | [Link](https://youtu.be/aPSBmej4ppc) | <img src="Images/the_thrill_of_the_fight/1.jpg" width="300" /> <img src="Images/the_thrill_of_the_fight/2.jpg" width="300" /> |

## TO-DOs

- [ ] Implement the calibration mechanism;

- [ ] Add audio (if possible);

- [ ] UI;
