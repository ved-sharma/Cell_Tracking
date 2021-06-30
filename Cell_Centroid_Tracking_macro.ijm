/* 
- This macro requires a thresholded time-lapse stack (binary). Run fill holes after thresholding the stack.
- Cells  should not be touching each other. If so, then user needs to separate them 
	manually by drawing a black line between the cells before running the macro.
- After tracking is completed, the macro prints a list of X, Y cell centroid coordinates
	for the cell being tracks through all the slices.
- This macro also works well for tracking H2B-labeled nucleus.

 Author: Ved P. Sharma, Email: vedsharma@gmail.com
 April 26, 2017 (version 08b)
*/

if(!((selectionType() == 4) || (selectionType() == 3)))
	exit("Trace the cell using either wand tool or the freehand selection in the start slice.");
startSlice = getSliceNumber();
num = nSlices;
for(i=0; i<num; i++) {
	setSlice(i+1);
	if(!is("binary"))
		exit("ERROR:\nSlice #"+(i+1)+" is not binary.\nThis macro only works with a thresholded 8-bit binary stack.");
}
setSlice(startSlice);

var fillColor;

List.setMeasurements;
inc = floor(List.getValue("Feret")/3);
Dialog.create("Cell Centroid Tracking...");
Dialog.addMessage("This macro needs a thresholded binary stack with\nvalues inside cell 255 and outside 0\nImportant: Run fill holes after thresholding the stack!");
Dialog.addNumber("Track till slice no.", nSlices);
Dialog.addMessage("For cell area changes from one frame to the next:");
Dialog.addNumber("Lower area tolerance (0-1): ", 0.5);
Dialog.addNumber("Upper area tolerance (>1): ", 1.5);
Dialog.addMessage("Search parameters:");
Dialog.addNumber("max Search distance (pixels):", 15*inc);
Dialog.addNumber("Search increment (pixels):", inc);
Dialog.addMessage("Notes:\nSuggested increment = Feret's diamter/ 3\nSuggested max distance = 15*increment");
Dialog.addCheckbox("List all shape descriptors (Circ, AR, Roundness)", false);
Dialog.addCheckbox("List Aspect Ratio", true);
Dialog.addCheckbox("Draw Overlays around the tracked cell", true);
Dialog.addCheckbox("Add centroids to ROI Manager", false);
Dialog.addCheckbox("Clear Log window if it's already open", true);
colors = newArray("none", "blue", "cyan", "green", "magenta", "red", "orange", "yellow", "olive", "teal", "purple", "brown");
Dialog.addRadioButtonGroup("Overlay Fill Color", colors, 3, 4, "none");
Dialog.show();

endSlice = Dialog.getNumber();
lowerAreaTol = Dialog.getNumber();
upperAreaTol = Dialog.getNumber();
maxDist = Dialog.getNumber();
inc = Dialog.getNumber();
sd = Dialog.getCheckbox();
ar = Dialog.getCheckbox();
overlay = Dialog.getCheckbox();
CentroidsToRM = Dialog.getCheckbox();
clearLog = Dialog.getCheckbox();
fillColor = Dialog.getRadioButton();
if(fillColor == "olive" || fillColor == "teal" || fillColor == "purple" || fillColor == "brown")
	getColorHexCode(); // needs Hex color code for the last four colors

getPixelSize(unit, pw, ph);
//print(unit); print(pw);print(ph);
//startSlice = getSliceNumber();
n = endSlice-startSlice+1;
x = newArray(n);
y = newArray(n);
if(sd) {
	circ = newArray(n);
	AR = newArray(n);
	roundness = newArray(n);
} 
else if(ar)
	AR = newArray(n);

var previousArea, currentArea; // global variables
previousArea = List.getValue("Area");
x[0] = (List.getValue("X")); // in microns if the image is calibrated
y[0] = (List.getValue("Y"));

if(overlay) {
	run("Overlay Options...", "stroke=red width=1 fill=&fillColor set");
	run("Add Selection...");
}
if(CentroidsToRM) {
		makePoint(x[0]/pw, y[0]/ph);
		roiManager("Add");
}

if(sd){
	circ[0] = (List.getValue("Circ."));
	AR[0] = (List.getValue("AR"));
	roundness[0] = (List.getValue("Round"));
}
else if(ar)
	AR[0] = (List.getValue("AR"));

//t1 = getTime();
for(i=1;i<n;i++) {
	setSlice(startSlice+i);
	p = x[i-1]/pw; q = y[i-1]/ph;

	if(getPixel(p, q) == 255)
		doWand(p, q);
	else
		findNewCentroid(x[i-1], y[i-1]); // returns new cell location ROI, selected with a wand tool

	List.setMeasurements;
	currentArea = List.getValue("Area");
	if(currentArea > upperAreaTol*previousArea)
		exit("ERROR: upper cell area tolerance breached!");
	if(currentArea < lowerAreaTol*previousArea)
		exit("ERROR: lower cell area tolerance breached!");

	x[i] = (List.getValue("X"));
	y[i] = (List.getValue("Y"));

	if(sd){
		circ[i] = (List.getValue("Circ."));
		AR[i] = (List.getValue("AR"));
		roundness[i] = (List.getValue("Round"));
	}
	else if (ar)
		AR[i] = (List.getValue("AR"));
	previousArea = currentArea;

	if(overlay)
		run("Add Selection...");
	if(CentroidsToRM) {
			makePoint(x[i]/pw, y[i]/ph);
			roiManager("Add");
	}
}
if (clearLog)
	print("\\Clear");
//timeTaken = (getTime() - t1)/1000; // in sec
//print("Total time taken = "+timeTaken);
print("--------------------------------------------------------");
print("The cell centroid coordinates (in "+unit+"):");
if(sd){
	print("Slice #\tX\tY\tCircularity\tAspect ratio\tRoundness");
	for(i=0;i<n;i++)
		print((startSlice+i)+"\t"+x[i]+"\t"+y[i] +"\t"+circ[i] +"\t"+AR[i] +"\t"+roundness[i]);
}
else if (ar) {
	print("Slice #\tX\tY\tAspect ratio");
	for(i=0;i<n;i++)
		print((startSlice+i)+"\t"+x[i]+"\t"+y[i] +"\t"+AR[i]);
}
else {
	print("Slice #\tX\tY");
	for(i=0;i<n;i++)
		print((startSlice+i)+"\t"+x[i]+"\t"+y[i]);
}
run("Select None");
setSlice(startSlice);
//-------------------------------------------
function findNewCentroid(a, b) {
//print("slice# "+getSliceNumber());
	for(rad=inc; rad<maxDist; rad+=inc) { // rad runs over the search radius
		for(angle=0, k=1; angle<2*PI; k++) {	// k runs over the angle from 0 to 2*PI
			p = (a/pw) + rad*cos(angle); q = (b/pw) + rad*sin(angle);
//makePoint(p,q);
//roiManager("Add");
			if(getPixel(p, q) == 255) {
		 		doWand(p, q);
				List.setMeasurements;
				currentArea = List.getValue("Area");
				if(currentArea < upperAreaTol*previousArea && currentArea > lowerAreaTol*previousArea)
					return;
			}
			angle = (k*inc)/rad;
		}
	}
	exit("No centroid found in the search range.\nTry increasing the search distance.");
}

function getColorHexCode() {
	if(fillColor == "olive")
		fillColor = "#808000"; //olive
	else if(fillColor == "teal")
		fillColor = "#008080"; // teal
	else if(fillColor == "purple")
		fillColor = "#7B68EE"; // medium slate blue
	else if(fillColor == "brown")
		fillColor = "#8B4513"; // saddle brown
}





