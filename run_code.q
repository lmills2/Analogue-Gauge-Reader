/Initialise EmbedPy
p)1+2
/Initialise globals
.gr.init[];

/Path to the gauge image file. Change this to where this image is stored on your computer.
path:"C:/q/dev/workspace/__nouser__/opencv/opencv/Images/gauge-1.jpg"

/Generate the calibration image for the gauge. This generates a file with markers on it that is used to configure the variables for the gauge.
.gr.calibrate[path]

/Read the gauge image file.
.gr.read[path]