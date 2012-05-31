(in-package :game-level)

(defparameter *world-position* '(0 0 -1)); '(-265 -435 -256))
(defun create-world ()
  (setf *world-position* '(0 0 -1))) ;'(-265 -435 -256)))

(defun step-world (world)
  (declare (ignore world)))

(defvar *game-data* nil)

(defun load-assets ()
  (format t "Starting asset load.~%")
  (free-assets)
  (let ((assets '((:ground #P"resources/ground.ai" 0 0)
                  (:ground-background #P"resources/ground-background.ai" 0 -25)
                  (:tree1 #P"resources/tree1.ai" 0 -100)
                  (:tree2 #P"resources/tree2.ai" 0 -70)
                  (:tree3 #P"resources/tree3.ai" 0 -80)
                  (:tree4 #P"resources/tree4.ai" 0 -160))))
    (loop for (key file x-offset z-offset) in assets do
          (return)
          (format t "Loading ~a...~%" file)
          (setf (getf *game-data* key)
                (list (cl-triangulation:triangulate (coerce (load-points-from-ai file :precision 2) 'vector))
                      x-offset
                      z-offset))))
  (setf (getf *game-data* :triangle) (make-gl-object :data #(-1.0 -1.0 0.0 1.0
                                                              1.0 -1.0 0.0 1.0
                                                              0.0  1.0 0.0 1.0)))
  (setf (getf *game-data* :prism) (make-gl-object :data #(-1.0 -1.0  0.0 1.0
                                                           1.0 -1.0  0.0 1.0
                                                           0.0  1.0  0.0 1.0
                                                           
                                                          -1.0 -1.0  0.0 1.0
                                                           0.0  0.0 -1.0 1.0
                                                           1.0 -1.0  0.0 1.0
                                                           
                                                          -1.0 -1.0  0.0 1.0
                                                           0.0  1.0  0.0 1.0
                                                           0.0  0.0 -1.0 1.0
                                                           
                                                           0.0  1.0  0.0 1.0
                                                           1.0 -1.0  0.0 1.0
                                                           0.0  0.0 -1.0 1.0)))
  (format t "Finished asset load.~%"))

(defun free-assets ()
  (loop for (nil obj) on *game-data* by #'cddr do
    (when (and (subtypep (type-of obj) 'gl-object)
               (gl-object-buffer obj))
      (gl:delete-buffers (list (gl-object-buffer obj))))))

(defun draw-world (world)
  (declare (ignore world))
  (gl:clear :color-buffer-bit :depth-buffer)
  (gl:use-program *default-shader-program*)
  (let* ((offset *world-position*)
         (frustum-scale 1.0)
         (fz-near 0.5)
         (fz-far 20.0)
         (matrix (make-array 16 :initial-element 0)))
    (setf (aref matrix 0) (/ frustum-scale (/ *window-width* *window-height*))
          (aref matrix 5) frustum-scale
          (aref matrix 10) (/ (+ fz-far fz-near) (- fz-near fz-far))
          (aref matrix 14) (/ (* 2 fz-far fz-near) (- fz-near fz-far))
          (aref matrix 11) -1.0)
    (gl:uniform-matrix (gl:get-uniform-location *default-shader-program* "perspectiveMatrix") 4 (vector matrix))
    (gl:uniformf (gl:get-uniform-location *default-shader-program* "offset") (car offset) (cadr offset) (caddr offset)))
  (let ((triangle (getf *game-data* :prism)))
    (gl:bind-buffer :array-buffer (gl-object-buffer triangle))
    (gl:enable-vertex-attrib-array 0)
    (gl:vertex-attrib-pointer 0 4 :float :false 0 (cffi:null-pointer))
    (gl:draw-arrays :triangles 0 12)
    (gl:disable-vertex-attrib-array 0)
    (gl:bind-buffer :array-buffer 0))
  (gl:use-program 0))

(defun draw-world_ (world)
  (declare (ignore world))
  ;; set up blending
  (gl:color 0 0 0)
  (gl:matrix-mode :modelview)
  (loop for (nil object-data) on *game-data* :by #'cddr do
    (let ((triangles (car object-data))
          (x-offset (cadr object-data))
          (z-offset (caddr object-data)))
      (gl:push-matrix)
      (gl:translate x-offset 0 z-offset)
      (gl:with-primitive :triangles
        (dolist (triangle triangles)
          (let* ((points (coerce triangle 'vector))
                 (points (if (cl-triangulation:polygon-clockwise-p points) (reverse points) points))
                 (a (aref points 0))
                 (b (aref points 1))
                 (c (aref points 2)))
            (gl:vertex (car a) (cadr a))
            (gl:vertex (car b) (cadr b))
            (gl:vertex (car c) (cadr c)))))
      (gl:pop-matrix)))
  (position-camera)
  (gl:flush))

(defun test-gl-funcs ()
  (format t "Running test func..~%")
  (format t "OpenGL version: ~a~%" (gl:get-string :version))
  (format t "Shader version: ~a~%" (gl:get-string :shading-language-version))
  (let ((program (create-default-shader-program)))
    (format t "Program: ~a~%" program)
    (when program (gl:delete-program program)))
  (gl:fog :fog-mode :linear)
  (gl:fog :fog-start 240.0)
  (gl:fog :fog-end 550.0)
  (gl:fog :fog-density 0.01))

