// http://hydraraptor.blogspot.com/2011/02/polyholes.html
module polyhole(h, d) {
    n = max(round(2 * d),3);
    rotate([0,0,180])
        cylinder(h = h, r = (d / 2) / cos (180 / n), $fn = n);
}

minSize = 1;
maxSize = 5;
n = 10;
spacing = maxSize + 2.5;
thickness = 2;
translate([-spacing * (n + 1) / 2, 0, 0]) difference() {
    translate([0, -spacing / 2, 0]) cube([spacing * (n + 1), spacing, thickness]);
    for (i = [1:n]) {
        diam = (maxSize - minSize) / n * i + minSize;
        translate([i * spacing, 0, -1]) polyhole(d = diam, h = thickness + 2);
    }
}

//build platform for debug
color([0.5,0.5,0.5,0.1]) translate([-50,-50,-1.01]) %cube([100,100,1]);
