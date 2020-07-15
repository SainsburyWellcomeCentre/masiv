# MaSIV README

<img src="https://raw.githubusercontent.com/wiki/SainsburyWellcomeCentre/masiv/images/Screen_shot.png" />

### What does MaSIV do? 

* MaSIV is an image viewer, designed for large (>100GB) 3D image datasets.
* It works by creating a downsampled stack, which is then navigated as you would a regular 3D image stack. 
* However, the program pulls data from the hard disk to a cache when zoomed in, allowing all the original detail to be viewed
* Features can be added using [plugins](https://github.com/alexanderbrown/masiv/wiki/Plugins)
* Works on Linux, OS X, and Windows

### What kind of data can I view in MaSIV? 

* In theory, MaSIV should work with *any* 3D image set, stored in disk in individual xy planes saved as .tif images
* MaSIV has been designed to accept data where each depth is stored in a separate tiff. A text file tells MaSIV which planes are to be grouped together into a single 3D image.
* Currently there no support for multiple channels.


### Installation

* Clone the repo and add only the root MaSIV directory to the MATLAB path.
* Dependencies:
    * Image Processing Toolbox
    * Parallel Processing Toolbox
    * Statistics and Machine Learning Toolbox
    * [Subpixel Registration](http://www.mathworks.com/matlabcentral/fileexchange/18401-efficient-subpixel-image-registration-by-cross-correlation)
* Run 'masiv'

### Using MaSIV 
Please see the [Wiki](https://github.com/alexanderbrown/masiv/wiki) for further information and [file an issue](https://github.com/alexanderbrown/masiv/issues) if you run into bugs or have a question.
