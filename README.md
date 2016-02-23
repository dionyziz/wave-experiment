# Wave simulation in WebGL
This is a simple [WebGL](http://en.wikipedia.org/wiki/WebGL) simulation of the 2D wave equation.

**[Launch the simulation](https://dionyziz.com/graphics/wave-experiment/)**

## Architecture
The root HTML file lies at index.html. This includes a basic CSS stylesheet, style.css, for elementary typography, as well as three Javascript files, three.js, TrackballControls.js, and main.js.

We use the de-facto standard [three.js](http://threejs.org/) WebGL Javascript library as our underlying framework for drawing 3D graphics. This provides basic rendering capabilities. We use the TrackballControls three.js plugin for elementary user interface controls which let the user rotate using drag and drop, zoom in and out using the mouse wheel, and panning using right-click drag and drop.

We use [CoffeeScript](http://coffeescript.org/) for our implementation. We chose CoffeeScript for its elegance and simplicity.

The main script file which performs the simulation is main.coffee, which is compiled to Javascript as main.js.

## How it works
The code consists of three portions, namely initialization, control handling, and integration. The core of the idea is implemented in the integration part.

Initialization is realized in the `init` function. The `init` function begins by creating a standard three.js scene, including a camera, a light, a scene, and the geometry with its materials. The geometry consists of a supporting cube of which the top face is the geometry which we manipulate to generate waves. The top face of the cube is a plane parallel to the xz plane of width and height `W` and `H` respectively. It is subdivided into `N` subquads in each direction, each of whose vertices' position is later manipulated to render waves.

Initialization has a sub-stage which introduces the initial condition of the world - a droplet at the center of the sea.

Control handling is realized in the function `hitTest`. We use a [standard three.js hit testing method](http://mrdoob.github.io/three.js/examples/canvas_interactive_cubes.html). When the user clicks on the screen, we unproject the location of the mouse into the 3D scene and detect the point of the sea that was clicked. We then modify the current waves to accommodate for a new droplet in that location.

The core of the program lies at the function `animate` and `integrate`. The `animate` function is the main loop of the simulation. It requests a rendering of the current graphical scene from three.js and subsequently calls `integrate` as many times as required to perform the physical simulation. `integrate` is responsible for the physical aspect of the calculations. It goes through all the vertices of the sea and evaluates their new locations based on certain physical formulae.

Our simulation is all performed at the CPU level. We are able to afford this, as our simulation algorithms are linear with respect to the number of vertices in question. If you want to run this simulation at higher speeds (a larger `C2` constant) or resolution (a larger `N`), we encourage you to fork this project and migrate this simulation from the CPU to the GPU level using shaders for computation.

## The math behind it
### Modelling
At the beginning, the plane is instantiated as a flat plane parallel to the xz plane. Subsequently, only the y coordinate of each vertex is modified for the simulation. This is a small offset approximation, which ignores conservation of mass and other effects that water often exhibits such as [hydraulic jumps](http://en.wikipedia.org/wiki/Hydraulic_jump). The water molecules can only move up and down - not horizontally. This is unrealistic physically, but works reasonably well for visually appealing results.

Therefore, our waves are modelled using a function `y = u(x, z, t)` which gives the height of each water molecule on the water surface with respect to its spatial location, given by `x` and `z`, and time `t`. All `x`, `z`, and `t` variables are also [discretized](https://en.wikipedia.org/wiki/Discretization) to be able to perform the required calculations for our model. This discretization splits up each spacial dimension into `N + 1` discrete points, while time is discretized into moments that are close to 16 milliseconds apart. The distance between two consecutive moments in time is denoted `dt` and may become smaller or larger depending on anomalies on the hosting platform (for example, a user switching tabs or using a CPU-intensive program in parallel). The bounds of our variables are as follows:

    t ≥ 0
    -W / 2 ≤ x ≤ W / 2
    -H / 2 ≤ y ≤ H / 2

We model the surface of the water using the [wave equation](https://en.wikipedia.org/wiki/Wave_equation). Alternative models that we decided not to use could involve the [shallow water equations](https://en.wikipedia.org/wiki/Shallow_water_equations) or even the full [Navier-Stokes equations](https://en.wikipedia.org/wiki/Navier%E2%80%93Stokes_equations) simplified to the desired degree. We encourage you to fork this project and play with alternatives.

### Initial and boundary conditions

We begin by introducing the [initial conditions](https://en.wikipedia.org/wiki/Initial_value_problem) of the world, a droplet at the center of the sea. The droplet geometry is implemented using a [2D Gaussian distribution](https://en.wikipedia.org/wiki/Gaussian_function). Therefore, our initial conditions are given as follows:

    u(x, z, 0) = A exp(-σx²) exp(-σz²)

Where `A` and `σ` are constant terms denoted respectively as `MAX_Y` and `SIGMA` in the code. As the sea is centered around the point (0, 0, 0), a Gaussian distribution with a zero offset does the job.

Throughout the simulation, we keep the [boundary](http://tutorial.math.lamar.edu/Classes/DE/BoundaryValueProblem.aspx) of the sea fixed with a height of zero; these are our [boundary conditions](https://en.wikipedia.org/wiki/Boundary_value_problem). While the Gaussian function is not zero at our finite boundaries, we use an appropriate sigma parameter such that it is close to zero. This introduces a space [discontinuity](http://en.wikipedia.org/wiki/Continuous_function) at the boundary, but it works reasonably well for our discretized model. Our boundary conditions are given:

    u(-W / 2, -H / 2, t) = u(W / 2, -H / 2, t) = u(-W / 2, H / 2, t) = u(W / 2, H / 2, t) = 0

When the user clicks on a particular location, we unproject the 2D point to retrieve an `x` and `z` for the 3D point that was clicked. If multiple points can be unprojected, we choose the one closer to the user. We then superimpose a new 2D Gaussian distribution to the existing function, introducing a time [discontinuity](http://en.wikipedia.org/wiki/Continuous_function) through direct position manipulation.

### Partial differential equation

The simulation runs by integrating the [wave equation](https://en.wikipedia.org/wiki/Wave_equation), a [partial differential equation](https://en.wikipedia.org/wiki/Partial_differential_equation) in three variables, at each moment in time. The equation forms the core of the simulation and is given below:

    ∇² u = ∂²u / ∂t²

Where `∇²` denotes the [Laplace operator](https://en.wikipedia.org/wiki/Laplace_operator). In our case, as our independent spatial variables are `x` and `z`, the Laplacian is given as follows:

    ∇²u = Δu = ∂²u / ∂x² + ∂²u / ∂z²

Where `∂` [denotes](http://tutorial.math.lamar.edu/Classes/CalcIII/PartialDerivatives.aspx) a [partial derivative](https://en.wikipedia.org/wiki/Partial_derivative). [Intuitively](https://www.youtube.com/watch?v=ck-r_qmNNG0), therefore, the wave equation [says](http://tutorial.math.lamar.edu/Classes/DE/TheWaveEquation.aspx) that the vertical acceleration of a water particle is proportional to the local spatial [curvature](https://en.wikipedia.org/wiki/Second_derivative) of the wave at that point in time.

### Integration

Between every two moments, we run an [iterated Euler integration method](https://en.wikipedia.org/wiki/Euler_method). Iterated means that if `dt` is too large, we break it into smaller dt's and run Euler's method on those, to avoid [numerical instability](http://en.wikipedia.org/wiki/Numerical_stability). We encourage you to fork this project and improve the integration method by converting it to a lower-error [Runge-Kutta integration method](https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_methods). This will allow higher simulation speeds with lower iteration resolution, while maintaining numerical stability.

Euler's method essentially [linearly approximates](http://en.wikipedia.org/wiki/Linear_approximation) the differential equations. We use the second [finite differences](http://en.wikipedia.org/wiki/Finite_difference) in space evaluated as 2nd order central difference approximations:

    ∂²u / ∂x² ≃ u(x + 1, z, t) - 2u(x, z, t) + u(x - 1, z, t)
    ∂²u / ∂z² ≃ u(x, z + 1, t) - 2u(x, z, t) + u(x, z - 1, t)

We then find the acceleration as the sum of these:

    ∂²u / ∂t² = ∂²u / ∂x² + ∂²u / ∂z²

Finally, the speed and position are evaluated using linear approximations:

    ∂u / ∂t ≃ dt ∂²u / ∂t²
    u ≃ dt ∂u / ∂t

Notice that `dt` is a finite number, since time is discretized. These are all evaluated for the next moment in time based on the current moment in time. To achieve the separation of moments in time, we perform a two-step process: In the first pass, we evaluate the new positions of the particles without altering the current positions of the particles. In the second pass, we update the locations of the particles based on our previous calculations. In this way, a moment in time does not affect itself.

### Proportionality and non-homogeneous term
The above equation is modified to introduce a proportionality factor, C², which the Laplacian is multiplied with to control the wave propagation rate, or the relationship between space and time.

Finally, the wave equation is made non-homogeneous by introducing a [damping term](http://uhaweb.hartford.edu/noonburg/m344lecture16.pdf) proportional to the current speed of each particle. This helps to reduce the energy of the waves as time goes by, essentially making the waves eventually vanish unless the user keeps interacting with them.

Under these modifications, the final partial differential equation becomes:

    ∇² u = C² ∂²u / ∂t² - D ∂u / ∂t

Where `C²` and `D` are constants denoted in the code as `C2` and `DAMPING` respectively.

## About the authors
[Petros Aggelatos](https://github.com/petrosagg) and [Dionysis Zindros](https://github.com/dionyziz) are [Electrical and Computer Engineering](http://ece.ntua.gr/) students mastering in [Computer Science](http://www.cslab.ntua.gr/) at the [National Technical University of Athens](http://www.ntua.gr/). We made this little demo for our own enjoyment, as we love computer graphics and physics, and to demonstrate some applications of the [partial differential equations course](http://www.ece.ntua.gr/en/education/undergraduate?view=ugcourse&id=49) of our school.

## License
> Copyright (C) 2013 Petros Aggelatos & Dionysis Zindros - {petrosagg,dionyziz}@gmail.com
> 
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
