(in-package :ghostie)

(defvar *perspective-matrix* nil)
(defvar *ortho-matrix* nil)
(defvar *view-matrix* nil)
(defvar *game-data* nil)

(defclass world ()
  ((physics :accessor world-physics :initform nil)
   (position :accessor world-position :initform '(0 0 -36))
   (level :accessor world-level :initform nil)
   (draw-meta :accessor world-draw-meta :initform nil)))

(defun create-world (&optional world)
  (let ((world (if world world (make-instance 'world))))
    ;; setup physics
    (let ((space (cpw:make-space :gravity-y -9.8d0)))
      (setf (cp-a:space-sleep-time-threshold (cpw:base-c space)) 3d0)
      (setf (cp-a:space-damping (cpw:base-c space)) 0.9d0)
      (setf (world-physics world) space))
    (unless (world-draw-meta world)
      (setf (getf (world-draw-meta world) :background) (hex-to-rgb "#222222" :type 'list)
            (getf (world-draw-meta world) :fog-amt) 0.0))
    world))

(defun world-game-cleanup (world)
  (dbg :info "Cleaning up game world~%")
  (when (world-level world)
    (level-cleanup (world-level world)))
  (let ((space (world-physics world)))
    (dolist (obj (append (cpw:space-bodies space)
                         (cpw:space-shapes space)
                         (cpw:space-joints space)))
      (cpw:destroy obj))
    (cpw:destroy space))
  (setf (world-physics world) nil
        (world-level world) nil
        (world-draw-meta world) nil)
  world)

(defun world-render-cleanup (world)
  (dbg :info "Cleaning up render world~%")
  (when (world-level world)
    (level-cleanup (world-level world)))
  (setf (world-level world) nil
        (world-draw-meta world) nil)
  (free-gl-assets)
  world)

(defun game-world-sync (world)
  (let ((level (world-level world)))
    (dolist (game-object (append (level-objects level)
                                 (level-actors level)))
      (sync-game-object-to-physics game-object :render t))
    (let ((pos (copy-tree (world-position world))))
      (enqueue (lambda (render-world)
                 (setf (world-position render-world) pos))
               :render))))

(defun step-game-world (world)
  (when *quit* (return-from step-game-world nil))
  (let ((space (world-physics world)))
    (cpw:space-step space :dt +dt+)
    (cpw:sync-space-bodies space)
    (dolist (game-object (level-objects (world-level world)))
      (sync-game-object-to-physics game-object))
    (dolist (actor (level-actors (world-level world)))
      (update-actor-state actor))
    (let ((actor (level-main-actor (world-level world))))
      (when actor
        ;(actor-stop actor)
        (sync-window-actor-position world actor)))))

(defun sync-window-actor-position (world actor)
  (let* ((position (game-object-position actor))
         (x (- (* (car position) .5)))
         (y (- (* (cadr position) .5))))
    (setf (world-position world) (list x (- y 50) (caddr (world-position world))))))

(defun free-gl-assets ()
  (loop for (nil obj) on *game-data* by #'cddr do
    (when (subtypep (type-of obj) 'gl-object)
      (free-gl-object obj)))
  (setf *game-data* nil))

(defun init-render (world)
  (free-gl-assets)
  (apply #'gl:clear-color (getf (world-draw-meta world) :background))
  ;; this is the quad we render our FBO texture onto
  (setf (getf *game-data* :quad) (make-gl-object :data '(((-1 -1 0) (1 -1 0) (-1 1 0)) ((1 -1 0) (1 1 0) (-1 1 0)))
                                                 :uv-map #(0 0 1 0 0 1 1 1))))

(defun load-game-assets (world)
  ;; load the current level
  (setf (world-level world) (load-level "trees"))
  (init-level-physics-objects world)
  (let ((level-meta (level-meta (world-level world))))
    (let* ((camera (getf level-meta :camera))
           (gravity (getf level-meta :gravity))
           (iterations (getf level-meta :physics-iterations))
           (background (if (getf level-meta :background)
                           (hex-to-rgb (getf level-meta :background) :type 'list)
                           (hex-to-rgb "#262524" :type 'list)))
           (fog-amt (getf (level-meta (world-level world)) :fog-amt))
           (fog-start (getf (level-meta (world-level world)) :fog-start))
           (fog-end (getf (level-meta (world-level world)) :fog-end))
           (fog-color (if (getf level-meta :fog-color)
                          (hex-to-rgb (getf level-meta :fog-color) :type 'list)
                          background)))
      (when iterations
        (cp-f:space-set-iterations (cpw:base-c (world-physics world)) (round iterations)))
      (when gravity
        (setf (cp-a:space-gravity-y (cpw:base-c (world-physics world))) (coerce gravity 'double-float)))
      (setf (getf (world-draw-meta world) :background) background
            (getf (world-draw-meta world) :fog-amt) (if fog-amt fog-amt 0.0)
            (getf (world-draw-meta world) :fog-start) (if fog-start fog-start 60.0)
            (getf (world-draw-meta world) :fog-end) (if fog-end fog-end 160.0)
            (getf (world-draw-meta world) :fog-color) fog-color)
      (when camera
        (setf (world-position *world*) camera))))

  (let ((meta (copy-tree (world-draw-meta world)))
        (position (copy-tree (world-position world))))
    (enqueue (lambda (render-world)
               (dbg :info "Copying game world meta to render world.~%")
               (apply #'gl:clear-color (getf meta :background))
               (setf (world-draw-meta render-world) meta
                     (world-position render-world) position))
             :render))
  (dbg :info "Finished asset load.~%"))

(defun draw-world (world)
  (when *quit* (return-from draw-world nil))
  (gl:bind-framebuffer-ext :framebuffer (gl-fbo-fbo (getf *render-objs* :fbo1)))
  (gl:clear :color-buffer-bit :depth-buffer)
  (unless (world-level world)
    (return-from draw-world nil))
  (use-shader :main)
  (set-shader-var #'gl:uniformf "fogAmt" (getf (world-draw-meta world) :fog-amt))
  (set-shader-var #'gl:uniformf "fogStart" (getf (world-draw-meta world) :fog-start))
  (set-shader-var #'gl:uniformf "fogEnd" (getf (world-draw-meta world) :fog-end))
  (when (getf (world-draw-meta world) :fog-color)
    (apply #'set-shader-var (append (list #'gl:uniformf "fogColor") (getf (world-draw-meta world) :fog-color))))
  (setf *view-matrix* (apply #'m-translate (world-position world)))
  (set-shader-matrix "cameraToClipMatrix" *perspective-matrix*)
  (when (world-level world)
    (draw-level (world-level world)))
  (gl:bind-framebuffer-ext :framebuffer 0)
  (let ((fbo (getf *render-objs* :fbo1)))
    (gl:clear :color-buffer-bit :depth-buffer-bit)
    (use-shader :dof)
    (set-shader-matrix "cameraToClipMatrix" *ortho-matrix*)
    (set-shader-var #'gl:uniformi "renderTexWidth" 600)
    (set-shader-var #'gl:uniformi "renderTexHeight" 600)
    (gl:active-texture :texture0)
    (gl:bind-texture :texture-2d (gl-fbo-tex fbo))
    (gl:generate-mipmap-ext :texture-2d)
    (set-shader-var #'gl:uniformi "renderTex" 0)
    (gl:active-texture :texture1)
    (gl:bind-texture :texture-2d (gl-fbo-depth fbo))
    (set-shader-var #'gl:uniformi "depthTex" 1))
  (draw-gl-object (getf *game-data* :quad))
  (use-shader 0))

(defun test-gl-funcs ()
  ;(gl:clear-color 1 1 1 1)
  (format t "OpenGL version: ~a~%" (gl:get-string :version))
  (format t "Shader version: ~a~%" (gl:get-string :shading-language-version))
  ;(format t "Extensions: ~a~%" (gl:get-string :extensions))
  (format t "Err: ~a~%" (gl:get-error)))

