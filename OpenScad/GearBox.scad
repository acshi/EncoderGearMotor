use <parametric_involute_gear_v5.0.scad>;

// http://hydraraptor.blogspot.com/2011/02/polyholes.html
module polyhole(h, d) {
    n = max(round(2 * d),3);
    rotate([0,0,180])
        cylinder(h = h, r = (d / 2) / cos (180 / n), $fn = n);
}

// Shift the motor in the x direction to help with teeth mating to the next gear stage.
// All the other gears are not as rigid as the motor, so the amount of play is different,
// in this case versus all the others.
motorXOffset = -1;
pinionTeeth = 10;
receivingGearTeeth = 42;

pitchRadiiAdjust = -0.7; // adjust the distance between gears so teeth mesh well

useHarringbone = 0;

clearance = 0.75;
minClearance = 0.45;

circularPitch = 0.5 * 360;//0.35 * 360; //distance between consecutive teeth * 360
gearAxleDiameter = 2.5; //use 1.75mm filament for the axles!

hubDiameter = 5; //around hole
rimWidth = 2; //around teeth
hubThickness = 3; //center
receivingGearThickness = 3.5;
pinionGearThickness = receivingGearThickness + 2.5;
gear0Thickness = receivingGearThickness;
pressureAngle = 25;
motorGearBoreClearance = 1.3; // 0.65 for makerbot
gearSupportDiameter = 5.25;
gearSupportDepth = 1.5;
stageOffset = 1;
encoderTickWidthRatio1 = 1 / 2;
encoderTickWidthRatio2 = 1 / 2;
encoderTickHeight = 3.5;
encoderEtchDepth = receivingGearThickness * 3 / 4;
addendum = circularPitch / 180; // Extension of the gear beyond the pitch radius

encoderAngularResolution = 0.18;
encoderTickEdgeOffset = 4.5;
// The intention now with these holes is to only provide a mark or a start
// But for consistancy they will need to be manually drilled out
encoderSmallHoleD = 1.0; // 1.4
encoderLargeHoleD = 2.0; // 2.7
homingTickEdgeOffset = 4.5;
// These holes don't need as much consistancy, hahaha...
homingSmallHoleD = 1.4; // 0.8 for makerbot
homingLargeHoleD = 4.6;
homingTicks = 3; // based on the same small and large hole diameters
encoderShaftBoreD = 5.6;
encoderShaftThickness = 1.75;

exitShaftDiameter = 8;
exitShaftLength = 16;

edgeBorder = 2;

motorHeight = 32;
motorDiameter = 23;
motorAxleDiameter = 2;
motorGearBoreDiameter = 1.8;
motorAxleHeight = 11;
motorRadius = motorDiameter / 2;
motorGearShelterThickness = 2;

insertRidgeThickness = 5; // To prevent motor from being inserted too far

angleStep = 2;
homingPeakN = 4;

wallThickness = 2.2;

screwHoleDiameter = 2.85; // 4-40
screwHoleSideOffset = 5; // distance in from each corner
nutTrapAdditionalWallThickness = 1.2;
nutTrapDepth = 2.4;
nutTrapDiameter = 6.35;

bottomWallThickness = wallThickness + nutTrapAdditionalWallThickness;

spacerThickness = 1.5; // The tubes around the screws that space the bottom and top plates

/*module arc(h, outerR, innerR, degrees) {
    render() {
        difference() {
            cylinder(h = h, r = outerR);
            cylinder(h = h, r = innerR);
            if (degrees < 180) {
                translate([-outerR, -outerR, 0]) cube([outerR * 2, outerR, h]);
                rotate([0, 0, degrees]) translate([-outerR, 0, 0]) cube([outerR * 2, outerR, h]);
            } else {
                difference() {
                    rotate([0, 0, degrees]) translate([-outerR, 0, 0])
                        cube([outerR * 2, outerR, h]);
                    translate([-outerR, 0, 0]) cube([outerR * 2, outerR, h]);
                }
            }
        }
    }
}*/

module harringboneGearHalf(boreDiam, teethNumber, gearThickness, flipped=0, hubD=hubDiameter, hubExtension=0) {
    gear(
        number_of_teeth=teethNumber,
        circular_pitch=circularPitch, 
        bore_diameter=boreDiam,
        hub_diameter=hubD,
        rim_width=rimWidth,
        hub_thickness=gearThickness / 2 + hubExtension,
        rim_thickness=gearThickness / 2,
        gear_thickness=gearThickness / 2,
        pressure_angle=pressureAngle,
        twist=200/teethNumber*(flipped ? -1 : 1));
}

module gearBoxGear(boreDiam, teethNumber, gearThickness, flipped=0, hubD=hubDiameter, hubExtension=0) {
    if (useHarringbone) {
        translate([0, 0, gearThickness / 2]) {
            harringboneGearHalf(boreDiam, teethNumber, gearThickness, flipped, hubD, hubExtension);
            mirror([0,0,1])
            harringboneGearHalf(boreDiam, teethNumber, gearThickness, flipped);
        }
    } else {
        // spur gear
        gear(
            number_of_teeth=teethNumber,
            circular_pitch=circularPitch,
            bore_diameter=boreDiam,
            hub_diameter=hubD,
            rim_width=rimWidth,
            hub_thickness=gearThickness + hubExtension,
            rim_thickness=gearThickness,
            gear_thickness=gearThickness,
            pressure_angle=pressureAngle);
    }
}

module gearBoxPinionGearWithBoreAndThickness(boreDiam, thickness) {
    gearBoxGear(
        boreDiam = boreDiam,
        teethNumber = pinionTeeth,
        gearThickness = thickness,
        flipped = 1);
}

module gearBoxMotorGear() {
    gearBoxPinionGearWithBoreAndThickness(motorGearBoreDiameter + motorGearBoreClearance, gear0Thickness);
}

module gearBoxPinionGear() {
    gearBoxPinionGearWithBoreAndThickness(gearAxleDiameter + clearance, pinionGearThickness);
}

module gearBoxReceivingGear() {
    gearBoxGear(
        boreDiam = gearAxleDiameter + clearance,
        teethNumber = receivingGearTeeth,
        gearThickness = receivingGearThickness);
}

module gearBoxExitGear() {
    difference() {
        union() {
            gearBoxGear(
                boreDiam = 0,
                teethNumber = receivingGearTeeth,
                gearThickness = receivingGearThickness,
                hubD = 0 * exitShaftDiameter,
                hubExtension = 0 * (exitShaftLength + wallThickness + clearance));
            // Hex shaft
            translate([0, 0, receivingGearThickness])
            #cylinder(h = exitShaftLength + wallThickness + clearance, d = exitShaftDiameter, $fn = 6);
        }
        
        // Since we set the bore diameter to 0 so that we don't get an open output shaft
        // we have to make a dent on the bottom side
        translate([0, 0, -clearance])
        #polyhole(d = gearAxleDiameter + clearance, h = gearSupportDepth + clearance * 2);
    }
}

function pitchRadiusOf(teeth) = teeth * circularPitch / 360;

// Driving motor
% translate([motorXOffset, 0, wallThickness / 2 - motorHeight]) {
    cylinder(h = motorHeight, d = motorDiameter);
    translate([0, 0, motorHeight]) cylinder(h = motorAxleHeight, d = motorAxleDiameter);
}

axleHeight = (receivingGearThickness + clearance) * 8;

pinionPitchR = pitchRadiusOf(pinionTeeth);
receivingGearPitchR = pitchRadiusOf(receivingGearTeeth);
pitchRadiiSum = pinionPitchR + receivingGearPitchR + pitchRadiiAdjust;

module gearBoxCompoundGear() {
    gearBoxReceivingGear();
    translate([0, 0, receivingGearThickness]) gearBoxPinionGear();
    // Axles won't actually be 3d-printed
    %cylinder(h = axleHeight, d = gearAxleDiameter + clearance, center = true);
}

// Assuming y is at the base of the target pinion
module gearSupports(heightAbove = 0, heightBelow = 0) {
    // Axle guards
    if (heightAbove > 0) {
        translate([0, 0, pinionGearThickness + minClearance]) {
            cylinder(h = heightAbove, d = gearSupportDiameter);
        }
    }
    if (heightBelow > 0) {
        translate([0, 0, -(minClearance + receivingGearThickness + heightBelow)]) {
            cylinder(h = heightBelow, d = gearSupportDiameter);
        }
    }
}

// Enough ticks to give us encoderAngularResolution of the output
// Making sure to use a multiple of 3
encoderTicks = ceil(360 / encoderAngularResolution / pow(receivingGearTeeth / pinionTeeth, 3) / 3) * 3;
echo("Encoder ticks:", encoderTicks);

encoderTickOuterR = receivingGearPitchR - encoderTickEdgeOffset;
encoderTickInnerR = encoderTickOuterR - encoderTickHeight;

homingTickR = receivingGearPitchR - homingTickEdgeOffset;

// that is, the alignment of the gears vertically
teethAlignmentOffset = (pinionGearThickness - receivingGearThickness) / 2;

// 4 stages of gears
module gear0() {
    translate([0, 0, stageOffset + wallThickness])
    translate([0, 0, -clearance]) gearBoxMotorGear();
}

module gear1() {
    translate([0, 0, stageOffset + wallThickness])
    translate([pitchRadiiSum, 0, 0]) difference() {
        gearBoxCompoundGear();
        theta = 0;
        totalThetaDivisions = (encoderTicks / 3) * 6;
        for (i = [0 : encoderTicks - 1]) {
            thetaDivOn = floor(i / 3) * 6 + ((i % 3 == 1) ? 1.75 : 0) + ((i % 3 == 2) ? 4 : 0);
            theta = thetaDivOn * 360 / totalThetaDivisions;
            diam = (encoderLargeHoleD - encoderSmallHoleD) / 2 * (i % 3) + encoderSmallHoleD;
            rotate([0, 0, theta]) translate([encoderTickOuterR, 0, -clearance])
                polyhole(d = diam, h = receivingGearThickness + 2 * clearance);
        }
    }
}

module gear2() {
    translate([0, 0, stageOffset + wallThickness])
    translate([pitchRadiiSum, pitchRadiiSum, receivingGearThickness + teethAlignmentOffset]) gearBoxCompoundGear();
}

module gear3() {
    translate([0, 0, stageOffset + wallThickness])
    translate([0, pitchRadiiSum, 2 * (receivingGearThickness + teethAlignmentOffset)]) gearBoxCompoundGear();
}

module gear4() {
    translate([0, 0, stageOffset + wallThickness])
    translate([0, 0, 3 * (receivingGearThickness + teethAlignmentOffset)]) {
        difference () {
            gearBoxExitGear();
            // Axle will not be 3d printed
            %cylinder(h = axleHeight, d = gearAxleDiameter + clearance, center = true);
            for (i = [0 : homingTicks - 1]) {
                theta = i * 360 / homingTicks;
                diam = (homingLargeHoleD - homingSmallHoleD) / (homingTicks - 1) * i + homingSmallHoleD;
                rotate([0, 0, theta]) translate([homingTickR, 0, -clearance])
                    polyhole(d = diam, h = receivingGearThickness + 2 * clearance);
            }
        }
    }
}

joinedStageWidth = receivingGearPitchR * 2 + pitchRadiiSum +
                   addendum * 2 + clearance * 2 + edgeBorder * 2;
echo ("Stage width:", joinedStageWidth);
echo ("Base offset from motor:", -baseOffsetFromMotor);
baseOffsetFromMotor = receivingGearPitchR + addendum + clearance + edgeBorder;
stageHeight = receivingGearThickness + teethAlignmentOffset;

spacerPos0 = [screwHoleSideOffset, screwHoleSideOffset, 0];
spacerPos1 = [joinedStageWidth - screwHoleSideOffset, screwHoleSideOffset, 0];
spacerPos2 = [screwHoleSideOffset, joinedStageWidth - screwHoleSideOffset, 0];
spacerPos3 = [joinedStageWidth - screwHoleSideOffset, joinedStageWidth - screwHoleSideOffset, 0];

topFaceOffset = wallThickness + stageOffset * 2 + stageHeight * 2 + receivingGearThickness + pinionGearThickness;
echo("Total height:", topFaceOffset + wallThickness);

module nutTrapScrewHole() {
    #polyhole(h = wallThickness + clearance * 2, d = screwHoleDiameter + 2 * clearance);
    translate([0, 0, -nutTrapAdditionalWallThickness])
    cylinder(d=nutTrapDiameter + 1.5 * clearance, h=nutTrapDepth, $fn=6);
}

module motorShelter() {
    // Axle mount protecting the motor gear
    difference() {
        shelterHeight = pinionGearThickness + clearance * 2 + motorGearShelterThickness;
        shelterInnerPeak = motorAxleHeight + clearance * 2;
        shelterPeakHeight = stageOffset + 3 * stageHeight; // As a support for the gear axle above
        union() {
            translate([-motorRadius / 3, -motorRadius - motorGearShelterThickness, wallThickness]) {
                // Main shelter
                cube([motorRadius / 2 + clearance,
                      motorDiameter + motorGearShelterThickness * 2,
                      shelterHeight]);
                // Axle support structure on top
                translate([0, motorDiameter / 2 + motorGearShelterThickness - motorAxleDiameter, shelterHeight])
                    cube([motorRadius / 2 + clearance, motorAxleDiameter * 2, shelterPeakHeight - shelterHeight]);
            }
            // Axle outdent on shelter top
            #translate([0, 0, wallThickness + shelterPeakHeight - clearance])
            cylinder(h = gearSupportDepth + clearance, d = gearAxleDiameter);
        }
        translate([-motorRadius / 3, -motorRadius - motorGearShelterThickness, wallThickness]) {
            translate([-clearance, motorGearShelterThickness, -clearance])
                difference() {
                    displacementH = pinionGearThickness + clearance * 3;
                    // Remove a section for the gear
                    cube([motorRadius / 2 + clearance * 3,
                          motorDiameter, displacementH]);
                    // This applies a chamfer to make good 45 degree angles
                    #rotate([45, 0, 0]) cube([motorRadius / 2 + clearance * 3, displacementH * 2, displacementH]);
                    translate([0, motorDiameter, 0])
                        #rotate([45, 0, 0]) cube([motorRadius / 2 + clearance * 3, displacementH, displacementH * 2]);
                }
        }
        // Make space for the end of motor axle 
        translate([-motorAxleDiameter * 0.75, -motorAxleDiameter * 0.75 - clearance, shelterHeight])
              cube([motorAxleDiameter * 1.5,
                    motorAxleDiameter * 1.5 + clearance * 2, shelterInnerPeak - shelterHeight]);
    }
}

module bottomPlate() {
    union() {
        homingShaftLength = stageOffset + stageHeight * 3 - minClearance;
        difference() {
            union() {
                translate([-baseOffsetFromMotor, -baseOffsetFromMotor, -nutTrapAdditionalWallThickness]) {
                    cube([joinedStageWidth, joinedStageWidth, bottomWallThickness]);
                }
                // "homing" encoder shaft
                translate([-homingTickR, 0, wallThickness])
                    cylinder(h = homingShaftLength, d = encoderShaftBoreD + clearance + encoderShaftThickness);
                // bottom-plate gear/axle supports supports
                translate([pitchRadiiSum, 0, wallThickness])
                    cylinder(h = stageOffset - minClearance, d = gearSupportDiameter);
                translate([pitchRadiiSum, pitchRadiiSum, wallThickness])
                    cylinder(h = stageOffset + stageHeight - minClearance, d = gearSupportDiameter);
                translate([0, pitchRadiiSum, wallThickness])
                    cylinder(h = stageOffset + stageHeight * 2 - minClearance, d = gearSupportDiameter);
                
                motorShelter();
            }
            //Holes for motor
            translate([motorXOffset, 0, -clearance - nutTrapAdditionalWallThickness]) {
                polyhole(h = clearance + bottomWallThickness - wallThickness / 2,
                         d = (motorRadius + clearance) * 2);
                higherHoleHeight = bottomWallThickness + clearance + 0.001;
                #intersection() {
                    polyhole(h = higherHoleHeight,
                            d = (motorRadius + clearance) * 2);
                    translate([0, 0, higherHoleHeight / 2 - minClearance])
                    cube([(motorRadius + clearance) * 2, (motorRadius + clearance - insertRidgeThickness) * 2, higherHoleHeight + minClearance * 2], center=true);
                }
            }
            
            // Screw holes and nut traps
            translate([-baseOffsetFromMotor, -baseOffsetFromMotor, -clearance]) {
                translate(spacerPos0) nutTrapScrewHole();
                translate(spacerPos1) nutTrapScrewHole();
                translate(spacerPos2) nutTrapScrewHole();
                translate(spacerPos3) nutTrapScrewHole();
            }
            
            // encoder shaft bore
            translate([pitchRadiiSum, -homingTickR, -nutTrapAdditionalWallThickness])
                polyhole(h = bottomWallThickness, d = encoderShaftBoreD + clearance);
            
            homingShaftBoreHalf = (homingShaftLength + bottomWallThickness) / 2;
            // "homing" encoder bore: insertion half
            translate([-homingTickR, 0, -nutTrapAdditionalWallThickness])
                polyhole(h = homingShaftBoreHalf, d = encoderShaftBoreD + clearance);
            // "homing" encoder bore: viewport/eye/focus cone half
            translate([-homingTickR, 0, -nutTrapAdditionalWallThickness + homingShaftBoreHalf])
                cylinder(h = homingShaftBoreHalf, d1 = encoderShaftBoreD + clearance, d2 = homingLargeHoleD + clearance);
            
            // Axle holes
            translate([pitchRadiiSum, 0, -nutTrapAdditionalWallThickness - minClearance])
                cylinder(h = topFaceOffset, d = gearAxleDiameter);
            translate([pitchRadiiSum, pitchRadiiSum, -nutTrapAdditionalWallThickness - minClearance])
                cylinder(h = topFaceOffset, d = gearAxleDiameter + minClearance);
            translate([0, pitchRadiiSum, -nutTrapAdditionalWallThickness - minClearance])
                cylinder(h = topFaceOffset, d = gearAxleDiameter + minClearance);
        }
    }
}

// top face
module topPlate() {
    gearSupportMaxH = -topFaceOffset + wallThickness + stageOffset + receivingGearThickness + pinionGearThickness + minClearance;
    translate([0, 0, topFaceOffset])
    difference() {
        encoderShaftLength = topFaceOffset - minClearance - receivingGearThickness - wallThickness - clearance;
        ridgeSupportHeight = -(gearSupportMaxH + stageHeight + receivingGearThickness);
        union() {
            translate([-baseOffsetFromMotor, -baseOffsetFromMotor, 0]) {
                // main plate
                cube([joinedStageWidth, joinedStageWidth, wallThickness]);
                // Spacers
                translate([0, 0, -topFaceOffset + wallThickness]) {
                    translate(spacerPos0)
                    cylinder(h = topFaceOffset, d = screwHoleDiameter + 2 * clearance + spacerThickness);
                    translate(spacerPos1)
                    cylinder(h = topFaceOffset, d = screwHoleDiameter + 2 * clearance + spacerThickness);
                    translate(spacerPos2)
                    cylinder(h = topFaceOffset, d = screwHoleDiameter + 2 * clearance + spacerThickness);
                    translate(spacerPos3)
                    cylinder(h = topFaceOffset, d = screwHoleDiameter + 2 * clearance + spacerThickness); 
                }
            }
            // top-plate gear/axle supports supports
            // put y at base of pinion to support
            translate([pitchRadiiSum, 0, gearSupportMaxH])
                cylinder(h = -gearSupportMaxH, d = gearSupportDiameter);
            translate([pitchRadiiSum, pitchRadiiSum, gearSupportMaxH + stageHeight])
                cylinder(h = -(gearSupportMaxH + stageHeight), d = gearSupportDiameter);
            translate([0, pitchRadiiSum, gearSupportMaxH + stageHeight * 2])
                cylinder(h = -(gearSupportMaxH + stageHeight * 2), d = gearSupportDiameter);
            // Ridge/support around output shaft to hold output gear in place
            translate([0, 0, -ridgeSupportHeight])
                cylinder(h = ridgeSupportHeight, d = exitShaftDiameter + clearance * 4);
            
            // Encoder sensor shaft
            translate([pitchRadiiSum, -encoderTickOuterR, -encoderShaftLength])
                cylinder(h = encoderShaftLength, d = encoderShaftBoreD + clearance + encoderShaftThickness);
        }
        // encoder shaft bore: insertion half
        encoderShaftBoreHalf = (encoderShaftLength + wallThickness) / 2;
        translate([pitchRadiiSum, -encoderTickOuterR, -encoderShaftLength + encoderShaftBoreHalf])
            #polyhole(h = encoderShaftBoreHalf, d = encoderShaftBoreD + clearance);
        // encoder shaft bore: pin hole cone half to focus on the encoder holes
        translate([pitchRadiiSum, -encoderTickOuterR, -encoderShaftLength])
            #cylinder(h = encoderShaftBoreHalf, d1 = encoderLargeHoleD + clearance, d2 = encoderShaftBoreD + clearance);
        // "homing" encoder view port
        translate([-encoderTickOuterR, 0, 0])
            #polyhole(h = wallThickness, d = encoderShaftBoreD + clearance);
        
        // Axle holes, these should be a looser fit than the ones on the bottom plate
        translate([pitchRadiiSum, 0, -topFaceOffset])
            #cylinder(h = topFaceOffset + wallThickness + minClearance, d = gearAxleDiameter + clearance / 2);
        translate([pitchRadiiSum, pitchRadiiSum, -topFaceOffset])
            #cylinder(h = topFaceOffset + wallThickness + minClearance, d = gearAxleDiameter + clearance / 2);
        translate([0, pitchRadiiSum, -topFaceOffset])
            #cylinder(h = topFaceOffset + wallThickness + minClearance, d = gearAxleDiameter + clearance / 2);
        
        //output shaft
        translate([0, 0, -clearance - stageOffset - ridgeSupportHeight])
            cylinder(h = wallThickness + stageOffset + ridgeSupportHeight + clearance * 2, d = exitShaftDiameter + clearance * 2);
        
        // Screw holes
        translate([-baseOffsetFromMotor, -baseOffsetFromMotor, -topFaceOffset + wallThickness]) {
            translate([screwHoleSideOffset, screwHoleSideOffset, 0])
                polyhole(h =  clearance + topFaceOffset, d = screwHoleDiameter + clearance);
            translate([joinedStageWidth - screwHoleSideOffset, screwHoleSideOffset, 0])
                polyhole(h = clearance + topFaceOffset, d = screwHoleDiameter + clearance);
            translate([screwHoleSideOffset, joinedStageWidth - screwHoleSideOffset, 0])
                polyhole(h = clearance + topFaceOffset, d = screwHoleDiameter + clearance);
            translate([joinedStageWidth - screwHoleSideOffset, joinedStageWidth - screwHoleSideOffset, 0])
                polyhole(h = clearance + topFaceOffset, d = screwHoleDiameter + clearance);
        }
    }
}

//gear0();
//gear1();
//gear2();
//gear3();
//gear4();
//topPlate();
bottomPlate();

gearRatio = receivingGearTeeth / pinionTeeth;
//pitchDiameter = pinionTeeth * circularPitch / 180;

/*
minimumNumberOfTeethPinion = (2 * addendum) / (sqrt(1 + gearRatio * (gearRatio + 2) * pow(sin(pressureAngle), 2)) - 1);
echo("Minimum number of teeth (pinion): >=", minimumNumberOfTeethPinion);

minimumNumberOfTeethRecevingGear = (2 * addendum) / (sqrt(1 + 1 / gearRatio * (1 / gearRatio + 2) * pow(sin(pressureAngle), 2)) - 1);
echo("Minimum number of teeth (receiving gear): >=", minimumNumberOfTeethRecevingGear);
*/

addendumConstant = 1;
minimumNumberOfTeethRack = (2 * addendumConstant) / pow(sin(pressureAngle), 2);
echo("Minimum number of teeth (rack): >=", minimumNumberOfTeethRack);

minimumNumberOfTeethPinion2 = sqrt(4 * pow(addendumConstant, 2) / pow(sin(pressureAngle), 2) + 4 * addendumConstant * receivingGearTeeth / pow(sin(pressureAngle), 2) + pow(receivingGearTeeth, 2)) - receivingGearTeeth;
echo("Minimum number of teeth (pinion): >=", minimumNumberOfTeethPinion2);

minimumNumberOfTeethRecevingGear2 = abs((4 * pow(addendumConstant, 2) / pow(sin(pressureAngle), 2) - pow(pinionTeeth, 2)) / (2 * (pinionTeeth - 2 * addendumConstant / pow(sin(pressureAngle), 2))));
echo("Minimum number of teeth (receiving gear): >=", minimumNumberOfTeethRecevingGear2);

echo("Line of action check: ", pinionTeeth + receivingGearTeeth, ">=", 2 * 3.14159 / tan(pressureAngle));

//build platform for debug
color([0.5,0.5,0.5,0.1]) translate([-50,-50,-1.01]) %cube([100,100,1]);