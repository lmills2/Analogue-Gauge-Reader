// @fileOverview Enter a description here...
// @returns {Type} Enter a return description here...
.gr.init:{[]
    .p.e"import cv2";
    `cv2 set .p.get[`cv2];
    .p.e"import numpy as np";
    `np set .p.get[`np];
    .p.e"import operator as op";
    `op set .p.get[`op];
    
    `pi set acos -1;
    
    .debug.gr.active:1b;
    .debug.gr.debugPath:"C:/q/dev/workspace/__nouser__/opencv/opencv/Images/debug";
    }

// @fileOverview Enter a description here...
// @returns {Type} Enter a return description here...
.gr.threshTest:{[gray; threshold; path]
    thresh: 175;
    maxValue: 255;

    s:(cv2`:threshold)[gray; thresh; maxValue; cv2[threshold]];
    /Using operator module to index into the return result as we can't reliably convert these from python -> q -> python    
    th:(op`:__getitem__)[s; 0];
    dst2:(op`:__getitem__)[s; 1];

    (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-", (1_string threshold), .util.fileExtension[path]; dst2]
    }

.util.tuple:{[list]
    if[0h > type list; list:enlist list];
	.p.eval["tuple"; list]
	}
.gr.calibrate:{[path]
	/path: string representing the path to the gauge image
    img:(cv2`:imread)[path];
    s:(img`:shape)`;
    height:s[0];
    width:s[1];

    gray:(cv2`:cvtColor)[img; cv2`:COLOR_BGR2GRAY];
    /for testing, output gray image
    if[.debug.gr.active; (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-calibration-gray", .util.fileExtension[path]; gray]];
    
    /detect circles
    /restricting the search from 35-48% of the possible radii gives fairly good results across different samples.  Remember that
    /these are pixel values which correspond to the possible radii search range.
    res:.gr.getCircles[gray; height; path];
    if[0 = count res[1]`; :()];
    averages:.gr.avgCircles[res[1]];
    gray:res[0];
    /draw center and circle
    (cv2`:circle)[img; .util.tuple averages`x`y; averages`r; .p.eval"(0,0,255)"; 3; cv2`:LINE_AA];
    (cv2`:circle)[img; .util.tuple averages`x`y; 2; .p.eval"(0,255,0)"; 3; cv2`:LINE_AA];

    /Save the image with the circle and center drawn
    if[.debug.gr.active; (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-calibration-circles", .util.fileExtension[path]; img]];

    /Goes through the motion of a circle and sets x and y values based on the set separation spacing.  Also adds text to each
    /line.  These lines and text labels serve as the reference point for the user to enter
    /NOTE: by default this approach sets 0/360 to be the +x axis (if the image has a cartesian grid in the middle), the addition
    /(i+9) in the text offset rotates the labels by 90 degrees so 0/360 is at the bottom (-y in cartesian).  So this assumes the
    /gauge is aligned in the image, but it can be adjusted by changing the value of 9 to something else.

    separation:10.0;
    interval:`int$floor 360%separation;
    
    p1:flip `int$floor (averages[`x] + 0.9 * averages[`r] * cos[(separation * pi * til interval) % 180]; averages[`y] + 0.9 * averages[`r] * sin[(separation * pi * til interval) % 180]);
    p2:flip `int$floor (averages[`x] + averages[`r] * cos[(separation * pi * til interval) % 180]; averages[`y] + averages[`r] * sin[(separation * pi * til interval) % 180]);

    text_offset_x:10;
    text_offset_y:5;
    p_text:flip `int$floor ((averages[`x] - text_offset_x) + 1.2 * averages[`r] * (np`:cos)[(separation * (9 + til interval) * pi) % 180]`; (averages[`y] + text_offset_y) + 1.2 * averages[`r] * (np`:sin)[(separation * (9 + til interval) * pi) % 180]`);

    /Draw the segments and text
    { [img; pts] (cv2`:line)[img; .util.tuple pts[0]; .util.tuple pts[1]; .p.eval"(0,255,0)"; 2] }[img;] each flip (p1;p2);
    .p.call[(cv2`:putText)`.;;()!()] each flip (img`.; string separation * til interval; .p.unwrap each (.util.tuple each p_text); (cv2`:FONT_HERSHEY_SIMPLEX)`.; 0.3; (.p.eval"(0,0,0)")`.; 1; (cv2`:LINE_AA)`.);
    /Save calibration image to disk
    /TODO:: Save this to a proper folder. Config for path?
    (cv2`:imwrite)[caliPath:("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-calibration-developer", .util.fileExtension[path]; img];   
    caliPath
	}
.util.fileNameFromPath:{[path]
    if[not 10h = type path; path: string path];
    /$[.z.o like "w*";
     /   last "\\" vs path;
	    last "/" vs path
    /]
	}
.util.getConfigForGauge:{[path]
    thisFunc:".util.getConfigForGauge";
	gaugeName:first "-" vs "_" sv $[1 < count n:"_" vs .util.fileNameWithoutExtensionFromPath[path]; -1_n; n];
    conf:GAUGE_CONFIG `$gaugeName;
    if[all null conf; .log.out[.z.h; thisFunc; "Unable to find config values for gauge named '", gaugeName, "'. Exiting ..."]; :()];
    if[any null `minAngle`maxAngle`minValue`maxValue`unit#conf; .log.out[.z.h; thisFunc; "Missing config values for gauge named '", gaugeName, "'. Missing values: ", ", " sv string where null `minAngle`maxAngle`minValue`maxValue`unit#conf, ". Exiting ..."]; :()];
    conf
	}
.gr.avgCircles:{[circles]
	/circles: embedPy object - ndarray (shape: 1,n,3)
    if[0 = count circles`; .log.out[.z.h;.gr.avgCircles; "No circles found. Exiting ... "]; :()];
    `x`y`r!`int$floor avg each flip raze circles`
	}
// @fileOverview Enter a description here...
// @returns {Type} Enter a return description here...
.log.out:{[x;y;z]
    0N!" ### " sv (string .z.p;string x;y;z)
    }
// @fileOverview Enter a description here...
// @returns {Type} Enter a return description here...
.gr.getCircles:{[gray; height; path]
    .log.out[.z.h; ".gr.getCircles"; "Detecting circles in gauge"];
    gray:(cv2`:medianBlur)[gray; 51]; 
    if[.debug.gr.active; (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-gray-blur", .util.fileExtension[path]; gray]];
    /detect circles
    /The values for these have been found through trial and error using a couple of different gauges.
    circs:.p.wrap .p.call[(cv2`:HoughCircles)`.;
        (gray`.;
        (cv2`:HOUGH_GRADIENT)`.;        /Detection method. This is the only one available
        0.5;                            /Inverse ratio of resolution
        15;                             /Minimum distance between detected centers
        (.p.eval"np.array([])")`.;      /Array which holds the x,y,z of the found circles
        150;                            /Upper threshold for internal canny edge detector
        45;                             /Threshold for center detection     
        0;                              /Minimum radius to be detected. If unknown, put zero as default.
        0);                             /Maximum radius to be detected. If unknown, put zero as default.
        ()!()];
    :(gray; circs)
    }

.util.fileNameWithoutExtensionFromPath:{[path]
    if[not 10h = type path; path: string path];
	"." sv -1_"."vs .util.fileNameFromPath path
	}
.gr.dist2Pts:{[x1;y1;x2;y2]
	sqrt[xexp[x2-x1; 2] + xexp[y2-y1;2]]
	}
.util.fileExtension:{[path]
	".", last "." vs .util.fileNameFromPath path
	}
.gr.read:{[path]
    
    thisFunc:".gr.read";
    .log.out[.z.h; thisFunc; "Begun for file ", path];

    .log.out[.z.h; thisFunc; "Loading config values for gauge"];
    conf:.util.getConfigForGauge[path];
    if[0 = count conf; :0n];
    
    .log.out[.z.h; thisFunc; "Loading image file ", .util.fileNameFromPath[path]];
    img:(cv2`:imread)[path];
    s:(img`:shape)`;
    height:s[0];
    width:s[1];

    gray:(cv2`:cvtColor)[img; cv2`:COLOR_BGR2GRAY];
    /for testing, output gray image
    if[.debug.gr.active; 
        .log.out[.z.h; thisFunc; "Saving debug image: gray"];
        (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-read-gray", .util.fileExtension[path]; gray]
        ];

    averages:.gr.avgCircles[.gr.getCircles[gray; height; path][1]];
    gray:(cv2`:medianBlur)[gray; 1]; 
    /Set threshold and maxValue
    thresh: $[null conf`threshold; 175; conf`threshold];
    maxValue: 255;

    s:(cv2`:threshold)[gray; thresh; maxValue; cv2`:THRESH_BINARY_INV];
    /Using operator module to index into the return result as we can't reliably convert these from python -> q -> python    
    th:(op`:__getitem__)[s; 0];
    dst2:(op`:__getitem__)[s; 1];

    if[.debug.gr.active; 
        .log.out[.z.h; thisFunc; "Saving debug image: dst2"];
        (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-read-threshold", .util.fileExtension[path]; dst2]
        ];

    .log.out[.z.h; thisFunc; "Calculating lines"];
    minLineLength:10;
    maxLineGap:$[null conf`maxLineGap;0;conf`maxLineGap];
    / rho is set to 3 to detect more lines, easier to get more then filter them out later
    lines:raze .p.py2q .p.call[(cv2`:HoughLinesP)`.; (); 
        `image`rho`theta`threshold`minLineLength`maxLineGap!
        (dst2`.;            /The image
        $[null conf`rho; 3; conf`rho];                  /Rho - Distance resolution of the accumulator in pixels
        %[(np`:pi)`;180];   /Theta - Angle resolution of the accumulator in radians
        100;                /Threshold - Accumulator threshold parameter. Only those lines are returned that get enough votes ( > threshold )
        minLineLength;      /Minimum line length. Line segments shorter than that are rejected.
        maxLineGap)];       /Maximum allowed gap between points on the same line to link them.
    
    diff1LowerBound:$[null conf`diff1LowerBound; 0.05; conf`diff1LowerBound]; /diff1LowerBound and diff1UpperBound determine how close the line should be from the center
    diff1UpperBound:$[null conf`diff1UpperBound; 0.45; conf`diff1UpperBound];
    diff2LowerBound:0.5; /diff2LowerBound and diff2UpperBound determine how close the other point of the line should be to the outside of the gauge
    diff2UpperBound:1.0;

    .log.out[.z.h; thisFunc; "Finding best line"];
    /assumes the first line is the best one
    finalLine:first {[diff1LowerBound; diff1UpperBound; diff2LowerBound; diff2UpperBound; averages; res; line]
        /line is aligned as: x1, y1, x2, y2
        diffs:(.gr.dist2Pts[averages`x; averages`y; line[0]; line[1]]; .gr.dist2Pts[averages`x; averages`y; line[2]; line[3]]);
        /set diff1 to be the smaller (closest to the center) of the two), makes the math easier
        if[diffs[0]>diffs[1]; diffs:reverse diffs];
        $[((diffs[0]<diff1UpperBound*averages`r) and (diffs[0]>diff1LowerBound*averages`r) and (diffs[1]<diff2UpperBound*averages`r)) and (diffs[1]>diff2LowerBound*averages`r);
            res, enlist line;
            res]
     }[diff1LowerBound; diff1UpperBound; diff2LowerBound; diff2UpperBound; averages]/[(); lines];

    if[0 = count finalLine; .log.out[.z.h; thisFunc; "Unable to find gauge needle. Exiting ..."]; :0n];
    
    (cv2`:line)[img; .util.tuple finalLine[0 1]; .util.tuple finalLine[2 3]; .p.eval"(0,255,0)"; 2];

    if[.debug.gr.active; 
        .log.out[.z.h; thisFunc; "Saving debug image: lines"];
        (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-read-lines", .util.fileExtension[path]; img]
        ];   

    .log.out[.z.h; thisFunc; "Calculating the angle"];
    /find the farthest point from the center to be what is used to determine the angle   
    $[.gr.dist2Pts[averages`x; averages`y; finalLine[0]; finalLine[1]] > .gr.dist2Pts[averages`x; averages`y; finalLine[2]; finalLine[3]];
        [
            xAngle: finalLine[0] - averages[`x];
            yAngle: averages[`y] - finalLine[1];
            ];
        [
            xAngle: finalLine[2] - averages[`x];
            yAngle: averages[`y] - finalLine[3];
            ]];
    /take the arc tan of y/x to find the angle
    res:(np`:rad2deg)[(np`:arctan)[(np`:divide)[`float$yAngle; `float$xAngle]]]`;

    finalAngle:$[ or[and[xAngle > 0; yAngle > 0]; and[xAngle > 0; yAngle < 0]]; 270 - res; 90 - res];

    finalRes:conf[`minValue] + *[-[finalAngle; conf[`minAngle]]; conf[`maxValue] - conf[`minValue]] % -[conf`maxAngle; conf`minAngle];
    if[.debug.gr.active; .log.out[.z.h; thisFunc; "Reading result: ", string[finalRes], " ", string conf`unit]];
    finalRes
	}
GAUGE_CONFIG:([gaugeName:`$()]minAngle:`float$();maxAngle:`float$();minValue:`float$();maxValue:`float$();unit:`$();threshold:`float$();maxLineGap:`float$();rho:`float$();
    diff1LowerBound:`float$();diff1UpperBound:`float$()) 
    upsert
    (
        (`gauge;40.3f;319f;0f;200f;`PSI;0n;0n;0n;0n;0n)
        ;(`boiler1;40f;312f;0f;15f;`PSI;125f;1f;0n;0n;0n) 
    )