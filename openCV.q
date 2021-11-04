.util.fileNameWithoutExtensionFromPath:{[path]
    if[not 10h = type path; path: string path];
	"." sv -1_"."vs .util.fileNameFromPath path
	}
.gr.read:{[path]
    
    thisFunc:".gr.read";
    .log.out[.z.h; thisFunc; "Begun for file ", path];

    .log.out[.z.h; thisFunc; "Loading config values for gauge"];
    conf:.util.getConfigForGauge[path];
    if[0 = count conf; 0n];
    
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

    /detect circles
    /restricting the search from 35-48% of the possible radii gives fairly good results across different samples.  Remember that
    /these are pixel values which correspond to the possible radii search range.
    .log.out[.z.h; thisFunc; "Detecting circles in gauge"];
    circles:.p.wrap .p.call[(cv2`:HoughCircles)`.;(gray`.; (cv2`:HOUGH_GRADIENT)`.; 1; 20;(.p.eval"np.array([])")`.; 100; 50; `int$height*0.35; `int$height*0.48);()!()];
    averages:.gr.avgCircles[circles];

    /Set threshold and maxValue
    thresh: 175;
    maxValue: 255;

    s:(cv2`:threshold)[gray; thresh; maxValue; cv2`:THRESH_BINARY_INV];
    
    th:(op`:__getitem__)[s; 0];
    dst2:(op`:__getitem__)[s; 1];

    if[.debug.gr.active; 
        .log.out[.z.h; thisFunc; "Saving debug image: dst2"];
        (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-read-threshold", .util.fileExtension[path]; dst2]
        ];

    .log.out[.z.h; thisFunc; "Calculating lines"];
    minLineLength:10;
    maxLineGap:0;
    / rho is set to 3 to detect more lines, easier to get more then filter them out later
    lines:raze .p.py2q .p.call[(cv2`:HoughLinesP)`.; (); `image`rho`theta`threshold`minLineLength`maxLineGap!(dst2`.; 3; %[(.gr.np`:pi)`;180]; 100; minLineLength; maxLineGap)];
    
    diff1LowerBound:0.10; /diff1LowerBound and diff1UpperBound determine how close the line should be from the center
    diff1UpperBound:0.15;
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
            res,enlist line;
            res]
     }[diff1LowerBound; diff1UpperBound; diff2LowerBound; diff2UpperBound; averages]/[(); lines];

    (cv2`:line)[img; .util.tuple finalLine[0 1]; .util.tuple finalLine[2 3]; .p.eval"(0,255,0)"; 2];

    if[.debug.gr.active; 
        .log.out[.z.h; thisFunc; "Saving debug image: img"];
        (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-read-lines", .util.fileExtension[path]; img]
        ];   

    .log.out[.z.h; thisFunc; "Calculating the angle"];
    /find the farthest point from the center to be what is used to determine the angle   
    $[.gr.dist2Pts[averages`x; averages`y; finalLine[0]; finalLine[1]] > .gr.dist2Pts[averages`x; averages`y; finalLine[2]; finalLine[3]];
        [
            xAngle: finalLine[0] - averages`x;
            yAngle: averages[`y] - finalLine[1];
            ];
        [
            xAngle: finalLine[2] - averages`x;
            yAngle: averages[`y] - finalLine[3];
            ]];
    /take the arc tan of y/x to find the angle
    res:(.gr.np`:rad2deg)[(.gr.np`:arctan)[(.gr.np`:divide)[`float$yAngle; `float$xAngle]]]`;

    finalAngle:$[ or[and[xAngle > 0; yAngle > 0]; and[xAngle > 0; yAngle < 0]]; 270 - res; 90 - res];

    finalRes:conf[`minValue] + *[-[finalAngle; conf[`minAngle]]; conf[`maxValue] - conf[`minValue]] % -[conf`maxAngle; conf`minAngle];
    if[.debug.gr.active; .log.out[.z.h; thisFunc; "Reading result: ", string finalRes]];
    finalRes
	}
.util.fileNameFromPath:{[path]
    if[not 10h = type path; path: string path];
    /$[.z.o like "w*";
     /   last "\\" vs path;
	    last "/" vs path
    /]
	}
.gr.calibrate:{[path]
	/path: string representing the path to the gauge image
    cv2:.gr.cv2;

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
    circles:.p.wrap .p.call[(cv2`:HoughCircles)`.;(gray`.; (cv2`:HOUGH_GRADIENT)`.; 1; 20;(.p.eval"np.array([])")`.; 100; 50; `int$height*0.35; `int$height*0.48);()!()];
    averages:.gr.avgCircles[circles];

    /draw center and circle
    (cv2`:circle)[img; .util.tuple averages`x`y; averages`r; .p.eval"(0,0,255)"; 3; cv2`:LINE_AA];
    (cv2`:circle)[img; .util.tuple averages`x`y; 2; .p.eval"(0,255,0)"; 3; cv2`:LINE_AA];

    /Save the image with the circle and center drawn
    if[.debug.gr.active; (cv2`:imwrite)[("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-circles", .util.fileExtension[path]; img]];

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
    p_text:flip `int$floor ((averages[`x] - text_offset_x) + 1.2 * averages[`r] * (.gr.np`:cos)[(separation * (9 + til interval) * pi) % 180]`; (averages[`y] + text_offset_y) + 1.2 * averages[`r] * (.gr.np`:sin)[(separation * (9 + til interval) * pi) % 180]`);

    /Draw the segments and text
    { [img; pts] (.gr.cv2`:line)[img; .util.tuple pts[0]; .util.tuple pts[1]; .p.eval"(0,255,0)"; 2] }[img;] each flip (p1;p2);
    .p.call[(cv2`:putText)`.;;()!()] each flip (img`.; string separation * til interval; .p.unwrap each (.util.tuple each p_text); (cv2`:FONT_HERSHEY_SIMPLEX)`.; 0.3; (.p.eval"(0,0,0)")`.; 1; (cv2`:LINE_AA)`.);
    /Save calibration image to disk
    /TODO:: Save this to a proper folder. Config for path?
    (cv2`:imwrite)[caliPath:("/" sv (.debug.gr.debugPath; .util.fileNameWithoutExtensionFromPath[path])),"-calibration-developer", .util.fileExtension[path]; img];   
    caliPath
	}
// @fileOverview Enter a description here...
// @returns {Type} Enter a return description here...
.log.out:{[x;y;z]
    0N!" - " sv (string .z.p;string x;y;z)
    }

.gr.dist2Pts:{[x1;y1;x2;y2]
	sqrt[xexp[x2-x1; 2] + xexp[y2-y1;2]]
	}
.gr.avgCircles:{[circles]
	/circles: embedPy object - ndarray (shape: 1,n,3)
    `x`y`r!`int$floor avg each flip raze circles`
	}
.util.getConfigForGauge:{[path]
    thisFunc:".util.getConfigForGauge";
	gaugeName:first "-" vs "_" sv $[1 < count n:"_" vs .util.fileNameWithoutExtensionFromPath[path]; -1_n; n];
    conf:GAUGE_CONFIG `$gaugeName;
    if[all null conf; 0N!"Unable to find config values for gauge named '", gaugeName, "'. Exiting ..."; :()];
    if[any null conf; 0N!"Missing config values for gauge named '", gaugeName, "'. Missing values: ", ", " sv string where null conf, ". Exiting ..."; :()];
    conf
	}
.util.fileExtension:{[path]
	".", last "." vs .util.fileNameFromPath path
	}
.util.tuple:{[list]
    if[0h > type list; list:enlist list];
	.p.eval["tuple"; list]
	}
GAUGE_CONFIG:([gaugeName:`$()]minAngle:`float$();maxAngle:`float$();minValue:`float$();maxValue:`float$();unit:`$()) 
    upsert
    (
         (`RANDOM_gauge;50f;320f;0f;200f;`PSI)
        ;(`gauge_sample;20f;340f;-30f;35f;`PSI)
        ;(`gauge;46f;316f;0f;200f;`PSI)    
    )