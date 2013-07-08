mesh = null
renderer = null
scene = null
camera = null
geometry = null
controls = null
projector = null


# simulation resolution
N = 60
# simulation size (in x and z directions)
W = 200
H = W

# depth of the cube on which it stands
D = 10

# wave propagation speed (relationship between time and space)
C = 0.04
C2 = C * C
# damping coefficient
DAMPING = 0.001
SIM_SPEED = 1
# precompute some deltas for our finite differences
DELTA_X = W / N
DELTA_X2 = DELTA_X * DELTA_X
DELTA_Z = H / N
DELTA_Z2 = DELTA_Z * DELTA_Z

# we're using iterated Euler's method
# specify iteration dt
MAX_DT = 12
# we won't be simulating beyond this dt
MAX_ITERATRED_DT = 100

# some constants for the initial state of the world
# the height of the original droplet
MAX_Y = 50
# the concentration of the original droplet
# this is the square of the inverse of the usual "sigma" used in the gaussian distribution
SIGMA = 0.01

# initialization of three.js, a basic camera, some lights, and the overall scene
init = ->
    camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 1, 10000)
    camera.position.z = 200
    camera.position.y = 150
    camera.position.x = 100

    scene = new THREE.Scene()

    light = new THREE.DirectionalLight(0xffffff)
    light.position.set(1, 1, 1)
    scene.add(light)

    # start with a flat plane which we'll deform accordingly
    geometry = new THREE.PlaneGeometry(W, H, N, N)
    # make it so that our wave function is in the form y = f(x, z, t)
    matrix = new THREE.Matrix4().makeRotationX(-Math.PI / 2)
    geometry.applyMatrix(matrix)

    initGeometry()

    materials = [
        new THREE.MeshPhongMaterial({color: 0x0099ff}),
        new THREE.MeshBasicMaterial({visible: false})
    ]

    mesh = new THREE.Mesh(geometry, materials[0])

    cubeGeometry = new THREE.CubeGeometry(W, D, H)
    face.materialIndex = 0 for face in cubeGeometry.faces
    cubeGeometry.faces[2].materialIndex = 1

    cubeMesh = new THREE.Mesh(cubeGeometry, new THREE.MeshFaceMaterial(materials))

    cubeMesh.position.set(0, -D / 2, 0)

    scene.add(mesh)
    scene.add(cubeMesh)

    controls = new THREE.TrackballControls(camera)

    projector = new THREE.Projector()

    renderer = new THREE.WebGLRenderer()
    updateViewport = ->
        renderer.setSize(window.innerWidth, window.innerHeight)
        camera.aspect = window.innerWidth / window.innerHeight
        camera.updateProjectionMatrix()
        controls.target.set(0, 0, 0)

    updateViewport()
    window.addEventListener('resize', updateViewport)
    document.addEventListener('mousedown', hitTest)

    document.body.appendChild(renderer.domElement)

now = Date.now()

# main loop function
animate = ->
    dt = Date.now() - now
    requestAnimationFrame(animate)
    renderer.render(scene, camera)
    controls.update()
    dt *= SIM_SPEED

    if dt > MAX_ITERATRED_DT
        dt = MAX_ITERATRED_DT
    
    # iterated Euler's method
    while dt > 0
        if dt > MAX_DT
            integrate(MAX_DT)
        else
            integrate(dt)
        dt -= MAX_DT
    now = Date.now()

# convert from (x, z) indices to an index in the vertex array
idx = (x, z) -> x + (N + 1) * z

# generate the initial condition for the simulation
initGeometry = () ->
    for vertex, index in geometry.vertices
        # vertex.y = MAX_Y * Math.sin((vertex.x + W / 2) / W * SPACE_X_OMEGA) * Math.sin((vertex.z + H / 2) / H * SPACE_Z_OMEGA) * Math.exp(-Math.abs(0.01 * vertex.x)) * Math.exp(-Math.abs(0.02 * vertex.z))
        # the initial condition is a symmetric 2d Gaussian
        # See http://en.wikipedia.org/wiki/Gaussian_function
        vertex.y = MAX_Y * Math.exp(-SIGMA * vertex.x * vertex.x) * Math.exp(-SIGMA * vertex.z * vertex.z)
        vertex.uy = 0
        vertex.ay = 0


integrate = (dt) ->
    v = geometry.vertices
    for z in [1...N]
        for x in [1...N]
            i = idx(x, z)
            # find neighbouring points in grid
            iPrevX = idx(x - 1, z)
            iNextX = idx(x + 1, z)
            iPrevZ = idx(x, z - 1)
            iNextZ = idx(x, z + 1)

            # evaluate the second space-derivatives using finite differences
            # see http://en.wikipedia.org/wiki/Finite_difference#Higher-order_differences
            d2x = (v[iNextX].y - 2 * v[i].y + v[iPrevX].y) / DELTA_X2
            d2z = (v[iNextZ].y - 2 * v[i].y + v[iPrevZ].y) / DELTA_Z2

            # the Wave partial differential equation in 2D
            # see https://en.wikipedia.org/wiki/Wave_equation
            # "d2x + d2z" is the spacial laplacian, ay is the acceleration w.r.t time
            v[i].ay = C2 * (d2x + d2z)

            # add a non-homogeneous term to introduce damping
            # see http://uhaweb.hartford.edu/noonburg/m344lecture16.pdf
            v[i].ay += -DAMPING * v[i].uy

            # use Euler integration to find the new velocity w.r.t. time
            # and the new vertical position
            # see https://en.wikipedia.org/wiki/Euler_integration
            v[i].uy += dt * v[i].ay
            v[i].newY = v[i].y + dt * v[i].uy

    # Commit the changes in the simulation
    # This is done in a separate step so that each simulation step doesn't affect itself
    for z in [1...N]
        for x in [1...N]
            i = idx(x, z)
            v[i].y = v[i].newY

    geometry.verticesNeedUpdate = true
    geometry.computeFaceNormals()
    geometry.computeVertexNormals()
    geometry.normalsNeedUpdate = true

hitTest = (e) ->
    # see http://mrdoob.github.io/three.js/examples/canvas_interactive_cubes.html for details on hit testing
    vector = new THREE.Vector3((e.clientX / window.innerWidth) * 2 - 1, -(e.clientY / window.innerHeight) * 2 + 1, 0.5)
    projector.unprojectVector(vector, camera)

    raycaster = new THREE.Raycaster(camera.position, vector.sub(camera.position).normalize())

    intersects = raycaster.intersectObjects([mesh])
    if intersects.length
        p = intersects[0].point
        # create a new initial condition (droplet) based on clicked location
        for vertex, index in geometry.vertices
            x = vertex.x - p.x
            z = vertex.z - p.z
            vertex.y += MAX_Y * Math.exp(-SIGMA * x * x) * Math.exp(-SIGMA * z * z)
            if vertex.x == -W / 2 or vertex.x == W / 2 or vertex.z == -H / 2 or vertex.z == H / 2
                vertex.y = 0

init()
animate()
