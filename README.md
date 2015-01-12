# goggleViewer README and Quickstart#


### What does goggleViewer do? ###

* goggleViewer is an experimental image viewer, designed for large (>100GB) 3D image datasets.
* It works by creating a downsampled stack, which is then navigated as you would a regular 3D image stack. 
* However, the program pulls data from the hard disk to a cache when zoomed in, allowing all the original detail to be viewed
* A plugin class can be easily subclassed to create user-defined plugins. For example, a cell counter plugin is included.



### How do I get set up? ###

* Clone the repo and add to the MATLAB path
* Dependencies:
    * MATLAB
        * Image Processing Toolbox
        * Parallel Processing Toolbox
        * Statistics Toolbox
    * [Subpixel Registration](http://www.mathworks.com/matlabcentral/fileexchange/18401-efficient-subpixel-image-registration-by-cross-correlation)
* Run 'goggleViewer'

### Using goggleViewer ###
* Run 'goggleViewer'
* Select the base path of the stitched experiment you would like to view
* Select the stack you would like to use as the base
    * New stacks can be generated in the selection GUI:
            * Select 'New'
            * Select the channel
            * Specify which slices to use. For example, to use every 3rd slice (in an experiment with 3000 slices), the correct settings would be 1, 3, 3000
            * Specify downsampling factor in XY. 10 works nicely for Alex. A reasonable starting point would be a downsampling factor that will reduce the size of the images to one roughly the number of pixels on your monitor. If the stitched images are 10,000 pixels wide, and your monitor has 1600x1200 pixels, a factor of 6-7 would be about right.
            * The downsampled stack will be created and saved to disk, then the viewer will open.

    

### This is crap, it doesn't work ###

* Email alex