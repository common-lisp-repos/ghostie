(in-package :game-level)

(defparameter *world-position* '(-265 -435 -256))
(defun create-world ()
  (setf *world-position* '(-265 -435 -256)))

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
          (format t "Loading ~a...~%" file)
          (let ((buffer (car (gl:gen-buffers 1))))
            (setf (getf *game-data* key)
                  (list (cl-triangulation:triangulate (coerce (load-points-from-ai file :precision 2) 'vector))
                        x-offset
                        z-offset
                        buffer)))))
  (format t "Finished asset load.~%"))

(defun free-assets ()
  (gl:delete-buffers (loop for (nil obj) on *game-data* by #'cddr collect (cdddr obj))))

(defun draw-world (world)
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

(defun position-camera ()
  (gl:load-identity)
  (apply #'gl:translate *world-position*))

(defun test-gl-funcs ()
  (format t "Running test func..~%")
  (format t "OpenGL version: ~a~%" (gl:get-string :version))
  (format t "Shader version: ~a~%" (gl:get-string :shading-language-version))
  (gl:fog :fog-mode :linear)
  (gl:fog :fog-start 240.0)
  (gl:fog :fog-end 550.0)
  (gl:fog :fog-density 0.01))

