#|
 This file is a part of harmony
 (c) 2017 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.harmony)

(stealth-mixin:define-stealth-mixin buffer () mixed:bip-buffer
  ((from :initform NIL :accessor from)
   (from-location :initform NIL :accessor from-location)
   (to :initform NIL :accessor to)
   (to-location :initform NIL :accessor to-location)))

(stealth-mixin:define-stealth-mixin segment () mixed:segment
  ())

(defmethod (setf cl-mixed:output-field) :after ((buffer buffer) (field (eql :buffer)) (location integer) (segment segment))
  (setf (from buffer) segment)
  (setf (from-location buffer) location))

(defmethod (setf cl-mixed:output-field) :after ((buffer buffer) (field (eql :pack)) (location integer) (segment segment))
  (setf (from buffer) segment)
  (setf (from-location buffer) location))

(defmethod (setf cl-mixed:input-field) :after ((buffer buffer) (field (eql :buffer)) (location integer) (segment segment))
  (setf (to buffer) segment)
  (setf (to-location buffer) location))

(defmethod (setf cl-mixed:input-field) :after ((buffer buffer) (field (eql :pack)) (location integer) (segment segment))
  (setf (to buffer) segment)
  (setf (to-location buffer) location))

(defmethod connect ((from segment) from-loc (to segment) to-loc)
  (let ((buffer (allocate-buffer *server*)))
    (mixed:connect from from-loc to to-loc buffer)))

(defmethod connect ((from segment) (all (eql T)) (to segment) (_all (eql T)))
  (loop for i from 0 below (getf (info from) :outputs)
        do (connect from i to i *server*)))

(defmethod disconnect ((from segment) from-loc &key (direction :output))
  (let ((buffer (ecase direction
                  (:output (mixed:output from from-loc))
                  (:input (mixed:input from from-loc)))))
    (setf (mixed:output (from buffer) (from-location buffer)) NIL)
    (setf (mixed:input (to buffer) (to-location buffer)) NIL)
    (free-buffer buffer *server*)))

(defmethod disconnect ((from segment) (all (eql T)) &key (direction :output))
  (loop for i from 0 below (ecase direction
                             (:output (getf (info from) :outputs))
                             (:input (getf (info from) :inputs)))
        do (disconnect from i :direction direction)))

(stealth-mixin:define-stealth-mixin source (segment) mixed:source
  ((repeat :initarg :repeat :initform 0 :accessor repeat)))

(defmethod (setf mixed:done-p) :around (value (source source))
  (case (repeat source)
    ((0 null)
     (call-next-method)
     (disconnect source T))
    ((T)
     (mixed:seek source 0))
    (T
     (mixed:seek source 0)
     (decf (repeat source))))
  value)

(defmethod mixed:unpacker ((source source))
  (to (mixed:pack source)))

;;; Always delegate to pack, since we never want to interfere between
;;; a source and its pack
(defmethod connect ((from source) from-loc (to segment) to-loc)
  (connect (mixed:unpacker from) from-loc to to-loc))

(defmethod disconnect ((from source) from-loc &key (direction :output))
  (disconnect (mixed:unpacker from) from-loc :direction direction))

(defmethod mixed:volume ((source source))
  (mixed:volue (mixed:unpacker source)))

(defmethod (setf mixed:volume) ((source source))
  (mixed:volue (mixed:unpacker source)))
