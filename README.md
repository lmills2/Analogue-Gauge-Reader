# Analogue Gauge Reader
## Requirements
This project can run in a local session of Developer. It requires EmbedPy to be installed.
## Required Python Packages
This project requires the following python packages:
- OpenCV - pip install opencv-python
- Numpy<br/>
Note: OpenCV requires Microsoft Visual C++ 14.0 available here: https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=BuildTools&rel=16
## Installation
- Download the file openCV.q from the repository. 
- In developer, create a new workspace and then create a new local repo.
- Right-click the repo and click New -> Upload Local Files. 
- Upload the openCV.q file, making sure to check the 'Import Q script as modules, functions, and data objects' checkbox.
- Expand the openCV module and open the .gr.init function. Change the path for the variable '.debug.gr.debugPath' to somewhere accessible on your system. The output images will be saved to this location.
- Download the gauge images from the repo and store them on your computer.
## Usage
Open the file 'run_code.q' and copy the contents into a scratchpad. The functions are laid out in order. 

The calibration function generates an image in the directory specified in '.debug.gr.debugPath'. Open the file and use it to fill in the values for GAUGE_CONFIG. The gauge name in this config is inferred from the file name. It searches by removing the file extension and anything after '-'. For example, the file name 'gauge-1.jpg' will resolve to the config gauge name 'gauge'.<br/>
![gauge-1-calibration-developer](https://user-images.githubusercontent.com/90591113/140465878-e4465699-89dd-41c4-a71a-f8bfc15dcb1c.jpg)<br/>
The values gaugeName, minAngle, maxAngle, minValue, maxValue and unit are required. The others are optional.

Once the calibration values have been entered, the function '.gr.read' can be called to read the value on the gauge. If the reading fails or is inaccurate, the optional values in the config can be tweaked to achieve a better result. With debug mode active ('.debug.gr.active:1b'), the read and calibrate functions will save images from each stage of the process. These can be used to tweak the values to get a good result.<br/>
![gauge-1-gray-blur](https://user-images.githubusercontent.com/90591113/140466280-66e82dc3-c8f5-4936-a3c4-345745b63abf.jpg)
![gauge-1-calibration-circles](https://user-images.githubusercontent.com/90591113/140466310-ede1363c-aeeb-48ef-ba3b-577bb2f92ef6.jpg)
![gauge-1-read-threshold](https://user-images.githubusercontent.com/90591113/140466906-f42dc7b9-0ca1-4abd-a7de-40e874609326.jpg)
![gauge-1-read-lines](https://user-images.githubusercontent.com/90591113/140466926-f7b85010-1560-49b7-9180-e5062edd0038.jpg)<br/>

![image](https://user-images.githubusercontent.com/90591113/140466867-5d00d7d1-89a8-4e32-93db-413505fb5bb8.png)


This is based on the work done in this repo: https://github.com/intel-iot-devkit/python-cv-samples/tree/master/examples/analog-gauge-reader
