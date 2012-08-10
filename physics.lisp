(in-package :ghostie)

(defun add-random-box (world)
  (let ((space (world-physics world))
        (x (- (random 100d0) 60)))
    (let* ((verts #((-1 -1) (-1 1) (1 1) (1 -1)))
           (moment (cpw:moment-for-poly 1 verts 0 0))
           (box-body (cpw:make-body (lambda () (cp:body-new 1d0 moment))))
           (box-shape (cpw:make-shape :poly box-body (lambda (body) (cpw:shape-poly body verts 0 0)))))
      (setf (cp-a:shape-u (cpw:base-c box-shape)) 0.7d0
            (cp-a:shape-e (cpw:base-c box-shape)) 0.3d0)
      (cp:body-set-angle (cpw:base-c box-body) (random PI))
      (cp:body-set-pos (cpw:base-c box-body) x 25d0)
      (let ((gl-objects (list (make-fake-gl-object :data (glu-tessellate:tessellate verts)
                                                   :position '(0 0 0)
                                                   :color (hex-to-rgb "#229944")))))
        (let ((game-object (make-game-object :type 'game-object
                                             :gl-objects gl-objects
                                             :physics box-body)))
          (cpw:space-add-body space box-body)
          (cpw:space-add-shape space box-shape)
          (push game-object (level-objects (world-level world)))
          (sync-game-object-to-physics game-object)
          (let ((render-game-object (make-game-object :type 'game-object
                                                      :position (copy-tree (game-object-position game-object))
                                                      :rotation (copy-tree (game-object-rotation game-object)))))
            (setf (game-object-render-ref game-object) render-game-object)
            (enqueue (lambda (render-world)
                       (dbg :info "Creating game object in render.~%")
                       (let ((gl-objects (loop for fake-gl-object in (game-object-gl-objects game-object)
                                               for gl-object = (make-gl-object-from-fake fake-gl-object)
                                               collect gl-object)))
                         (setf (game-object-gl-objects render-game-object) gl-objects)
                         (push render-game-object (level-objects (world-level render-world)))))
                     :render)))))))