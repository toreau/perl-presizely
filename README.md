# Presizely

## Overview

Presizely is an easy-to-use online service for transforming images. The main focus is on resizing/scaling images, but several other types of transformations are also possible.

**The service is currently under beta testing and should not be used in production environments.**

## Try it out with Docker

```
$ git clone git@github.com:toreau/Presizely.git
$ cd Presizely
$ docker build -t presizely .
$ docker run -p 3000:3000 presizely
```

## Usage

### Serve original image as-is

The simplest way of using Presizely is to just hand it the URL to the original image without specifying any transformations.

```
http://127.0.0.1:3000/http://example.com/image.jpg
```

### Auto height (aspect ratio preserved)

One number to the left of an `x` sets a specific width and calculates the height based on aspect ratio.

```
http://127.0.0.1:3000/1024x/http://example.com/image.jpg
```

### Auto width (aspect ratio preserved)

One number to the right of an `x` sets a specific height and calculates the width based on aspect ratio.

```
http://127.0.0.1:3000/x1024/http://example.com/image.jpg
```

### Exact width and height

Two numbers separated by an `x` resizes the image to the exact dimensions specified.

```
http://127.0.0.1:3000/1024x1024/http://example.com/image.jpg
```

You can also resize images based on a ratio. If any of the numbers explained above is a decimal number, it will be treated as a ratio. Here the image will be resized to 50 % of its width, with aspect ratio preserved;

```
http://127.0.0.1:3000/0.5x/http://example.com/image.jpg
```

### Rotation

One number to the right of an `r` rotates the image a specific number of degrees clockwise. Use a negative number to rotate anticlockwise.

```
http://127.0.0.1:3000/r90/http://example.com/image.jpg
```

**NOTE!** The background color for corners is at the moment set to white. It should be possible to choose the color, or transparency, and this will be rectified in a later version.

### Cropping

A set of numbers to the right of a `c` crops the image;

```
http://127.0.0.1:3000/c1024x1024-0x0/http://example.com/image.jpg
```

The two first numbers are the width and the height of the "crop window", while the two last numbers are the x and y value for where you want the "crop window" to be positioned.

### Black and white

Use the `bw` parameter to make the image black and white.

```
http://127.0.0.1:3000/bw/http://example.com/image.jpg
```

### Flipping

Use the `fh` and/or `fv` parameter to flip the image horizontally and/or vertically, respectively.

```
http://127.0.0.1:3000/fh,fv/http://example.com/image.jpg
```

### Quality (JPEG only)

One number to the right of a `q` changes the quality of the image.

```
http://127.0.0.1:3000/q75/http://example.com/image.jpg
```

### Optimization (JPEG only)

Use the `o` parameter to optimize the Huffman coding tables. Compared to the other actions, this will have a bigger performance hit, depending on the image size.

```
http://127.0.0.1:3000/o/http://example.com/image.jpg
```

### Chaining

It's possible to chain image actions by separating them with a comma. Please note that cropping is always performed first, resizing is always performed second,
while the other actions are performed in an arbitrary order.

```
http://127.0.0.1:3000/1024x,q75,r90/http://example.com/image.jpg
```

### Non-image URLs

If Presizely is given a URL to an HTML page, like a news article, it will look for the image representing the page, specifically the `og:image` and `twitter:image` meta tags and use the image URL found (if any).

```
http://127.0.0.1:3000/1024x,q75,r90/http://example.com/sports/article.html
```

### Drop shadow

*Coming soon...*

## Behind the scenes

### Caching

Presizely have two cache levels. First, the original image is cached. Second, the processed image (ie. after all the actions have been performed on the image) is cached based on the actions done to it.

The two cache levels behaves the same, except that the most frequently accessed images (after transformation) are also stored in an in-memory L1 cache.

### Limitations

* Original image can't be larger than 64MB, but this can be changed by setting the `MOJO_MAX_MESSAGE_SIZE` configuration variable to the max. number of bytes you want.
* Only the most popular (...) image formats are supported; JPEG, PNG and GIF are safe bets.
* Animated GIFs can be transformed, but only the first image in the animation will be returned at the moment.

## Performance

Presizely's performance depends primarily on the hardware (specifically the CPU) it runs on when it downloads and transforms an image. Once an image is downloaded and
transformed, it's cached, so performance shouldn't be a problem. However, if you cache your images on disk, IO can be an issue. Presizely therefore does all the caching
in the background, so that the client won't have to wait for the transformed image to be delivered.

On my server, an Intel Xeon E3-1246 3.50GHz, with Presizely set up to run with 16 workers, it can easily handle 2,500 requests per second *after* the image has been
cached. Your mileage may wary, of course.

## Thanks to...

* [Perl](https://www.perl.org/)
* [Mojolicious](http://mojolicious.org/)
* [Imager](https://metacpan.org/pod/Imager)
* ...and many other excellent [CPAN](https://metacpan.org/) modules!

## Copyright

Tore Aursand © 2016, ALL RIGHTS RESERVED
