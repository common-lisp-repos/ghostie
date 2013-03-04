;;; TODO: Allow setting arbiter elasticity/friction/surface velocity from the
;;; cpw:arbiter object passed into callbacks (ie sync it in these callbacks)
;;; and also allow a triggered event to cancel/confirm the collision
(in-package :ghostie)

(defun get-bodies-from-arbiter (arbiter)
  "Given an arbiter, get the two game bodies (cpw) that collided."
  (cffi:with-foreign-objects ((a :pointer)
                              (b :pointer))
    (cp-f:arbiter-get-shapes arbiter a b)
    (let ((body-a (cpw:find-body-from-pointer (cp-a:shape-body (cffi:mem-aref a :pointer))))
          (body-b (cpw:find-body-from-pointer (cp-a:shape-body (cffi:mem-aref b :pointer)))))
      (values body-a body-b))))

(defmacro define-collision-callback (name (arbiter-var body1-var body2-var &key (sync t)) &body body)
  `(defun ,name (arbiter space data)
     (declare (ignore space data))
     ;; let's be careful here since a condition can derail chipmunk and creash
     ;; the entire app
     (handler-case
       (multiple-value-bind (,body1-var ,body2-var)
           (get-bodies-from-arbiter arbiter)
         (let ((,arbiter-var (cpw:make-arbiter arbiter)))
           ,@body
           (when ,sync (cpw:sync-arbiter-to-c ,arbiter-var))
           (if (cpw:arbiter-ignore-collision ,arbiter-var)
               cp:+false+
               cp:+true+)))
       (ccl::invalid-memory-access (e)
         (dbg :error "(physics) Invalid memory access =[ ~a~%" e))
       (error (e)
         (dbg :error "(physics) Collision event error (begin): ~a~%" e)))
     cp:+true+))

;; TODO call make-arbiter only once, and store the result in the arbiter c obj
;; itself. note that creating a pointer, setting it into a hash table, and
;; dereferencing it to get the arbiter data might be slower than just calling
;; make-arbiter for each collision call (but need to benchmark before assuming)
(define-collision-callback collision-begin (arbiter-data body1 body2)
  (trigger :collision-begin body1 body2 arbiter-data)
  (trigger :collision-begin body2 body1 arbiter-data))

(define-collision-callback collision-pre-solve (arbiter-data body1 body2)
  (trigger :collision-pre body1 body2 arbiter-data)
  (trigger :collision-pre body2 body1 arbiter-data))

(define-collision-callback collision-post-solve (arbiter-data body1 body2)
  (trigger :collision-post body1 body2 arbiter-data)
  (trigger :collision-post body2 body1 arbiter-data))

(define-collision-callback collision-separate (arbiter-data body1 body2)
  (trigger :collision-separate body1 body2 arbiter-data)
  (trigger :collision-separate body2 body1 arbiter-data))

(cffi:defcallback cp-begin :int ((arb :pointer) (space :pointer) (data :pointer))
  (collision-begin arb space data))
(cffi:defcallback cp-pre-solve :int ((arb :pointer) (space :pointer) (data :pointer))
  (collision-pre-solve arb space data))
(cffi:defcallback cp-post-solve :void ((arb :pointer) (space :pointer) (data :pointer))
  (collision-post-solve arb space data))
(cffi:defcallback cp-separate :void ((arb :pointer) (space :pointer) (data :pointer))
  (collision-separate arb space data))

