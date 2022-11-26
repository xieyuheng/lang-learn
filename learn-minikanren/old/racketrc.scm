(require racket/enter)
(require setup/dirs)
;; (require minikanren)

(define-syntax lambdag@
  (syntax-rules ()
    ((_ (s) e) (lambda (s) e))))

(define-syntax lambdaf@
  (syntax-rules ()
    ((_ () e) (lambda () e))))

(define-syntax rhs
  (syntax-rules ()
    ((rhs p) (cdr p))))

(define-syntax lhs
  (syntax-rules ()
    ((lhs p) (car p))))

(define-syntax var
  (syntax-rules ()
    ((var w) (vector w))))

(define-syntax var?
  (syntax-rules ()
    ((var? w) (vector? w))))

(define-syntax size-s
  (syntax-rules ()
    ((size-s ls) (length ls))))

(define empty-s '())

(define walk
  (lambda (v s)
    (cond
      ((var? v)
       (cond
         ((assq v s) =>
          (lambda (a)
            (let ((v^ (rhs a)))
              (walk v^ s))))
         (else v)))
      (else v))))

(define ext-s
  (lambda (x v s)
    (cons `(,x . ,v) s)))

(define unify
  (lambda (v w s)
    (let ((v (walk v s))
          (w (walk w s)))
      (cond
        ((eq? v w) s)
        ((var? v) (ext-s v w s))
        ((var? w) (ext-s w v s))
        ((and (pair? v) (pair? w))
         (cond
           ((unify (car v) (car w) s) =>
            (lambda (s)
              (unify (cdr v) (cdr w) s)))
           (else #f)))
        ((equal? v w) s)
        (else #f)))))

(define ext-s-check
  (lambda (x v s)
    (cond
      ((occurs-check x v s) #f)
      (else (ext-s x v s)))))

(define occurs-check
  (lambda (x v s)
    (let ((v (walk v s)))
      (cond
        ((var? v) (eq? v x))
        ((pair? v)
         (or
           (occurs-check x (car v) s)
           (occurs-check x (cdr v) s)))
        (else #f)))))

(define unify-check
  (lambda (v w s)
    (let ((v (walk v s))
          (w (walk w s)))
      (cond
        ((eq? v w) s)
        ((var? v) (ext-s-check v w s))
        ((var? w) (ext-s-check w v s))
        ((and (pair? v) (pair? w))
         (cond
           ((unify-check (car v) (car w) s) =>
            (lambda (s)
              (unify-check (cdr v) (cdr w) s)))
           (else #f)))
        ((equal? v w) s)
        (else #f)))))

(define walk*
  (lambda (v s)
    (let ((v (walk v s)))
      (cond
        ((var? v) v)
        ((pair? v)
         (cons
           (walk* (car v) s)
           (walk* (cdr v) s)))
        (else v)))))

(define reify-s
  (lambda (v s)
    (let ((v (walk v s)))
      (cond
        ((var? v) (ext-s v (reify-name (size-s s)) s))
        ((pair? v) (reify-s (cdr v) (reify-s (car v) s)))
        (else s)))))

(define reify-name
  (lambda (n)
    (string->symbol
     ;; (string-append "_" "." (number->string n))
     (string-append ":" (number->string n)))))

(define reify
  (lambda (v)
    (walk* v (reify-s v empty-s))))

(define-syntax run
  (syntax-rules ()
    ((_ n^ (x) g ...)
     (let ((n n^) (x (var 'x)))
       (if (or (not n) (> n 0))
         (map-inf n
           (lambda (s) (reify (walk* x s)))
           ((all g ...) empty-s))
         '())))))

(define-syntax case-inf
  (syntax-rules ()
    ((_ e on-zero ((a^) on-one) ((a f) on-choice))
     (let ((a-inf e))
       (cond
         ((not a-inf) on-zero)
         ((not (and
                 (pair? a-inf)
                 (procedure? (cdr a-inf))))
          (let ((a^ a-inf))
            on-one))
         (else (let ((a (car a-inf))
                     (f (cdr a-inf)))
                 on-choice)))))))

(define-syntax mzero
  (syntax-rules ()
    ((_) #f)))

(define-syntax unit
  (syntax-rules ()
    ((_ a) a)))

(define-syntax choice
  (syntax-rules ()
    ((_ a f) (cons a f))))

(define map-inf
  (lambda (n p a-inf)
    (case-inf a-inf
      '()
      ((a)
       (cons (p a) '()))
      ((a f)
       (cons (p a)
         (cond
           ((not n) (map-inf n p (f)))
           ((> n 1) (map-inf (- n 1) p (f)))
           (else '())))))))

(define ==
  (lambda (v w)
    (lambdag@ (s)
      (cond
        ((unify v w s) => succeed)
        (else (fail s))))))

(define ==-check
  (lambda (v w)
    (lambdag@ (s)
      (cond
        ((unify-check v w s) => succeed)
        (else (fail s))))))

(define-syntax fresh
  (syntax-rules ()
    ((_ (x ...) g ...)
     (lambdag@ (s)
       (let ((x (var 'x)) ...)
         ((all g ...) s))))))

(define-syntax all
  (syntax-rules ()
    ((_) succeed)
    ((_ g) (lambdag@ (s) (g s)))
    ((_ g^ g ...) (lambdag@ (s) (bind (g^ s) (all g ...))))))

(define-syntax conde
  (syntax-rules (else)
    ((_) fail)
    ((_ (else g0 g ...)) (all g0 g ...))
    ((_ (g0 g ...) c ...)
     (anye (all g0 g ...) (conde c ...)))))

(define succeed (lambdag@ (s) (unit s)))

(define fail (lambdag@ (s) (mzero)))

(define bind
  (lambda (a-inf g)
    (case-inf a-inf
      (mzero)
      ((a) (g a))
      ((a f) (mplus (g a)
               (lambdaf@ () (bind (f) g)))))))

(define mplus
  (lambda (a-inf f)
    (case-inf a-inf
      (f)
      ((a) (choice a f))
      ((a f0) (choice a
                (lambdaf@ () (mplus (f0) f)))))))

(define-syntax anye
  (syntax-rules ()
    ((_ g1 g2)
     (lambdag@ (s)
       (mplus (g1 s)
         (lambdaf@ () (g2 s)))))))

(define-syntax alli
  (syntax-rules ()
    ((_) succeed)
    ((_ g) (lambdag@ (s) (g s)))
    ((_ g^ g ...)
     (lambdag@ (s)
       (bindi (g^ s) (alli g ...))))))

(define-syntax condi
  (syntax-rules (else)
    ((_) fail)
    ((_ (else g0 g ...)) (all g0 g ...))
    ((_ (g0 g ...) c ...)
     (anyi (all g0 g ...) (condi c ...)))))

(define-syntax anyi
  (syntax-rules ()
    ((_ g1 g2)
     (lambdag@ (s)
       (mplusi (g1 s)
         (lambdaf@ () (g2 s)))))))

(define bindi
  (lambda (a-inf g)
    (case-inf a-inf
      (mzero)
      ((a) (g a))
      ((a f) (mplusi (g a)
               (lambdaf@ () (bindi (f) g)))))))

(define mplusi
  (lambda (a-inf f)
    (case-inf a-inf
      (f)
      ((a) (choice a f))
      ((a f0) (choice a
                (lambdaf@ () (mplusi (f) f0)))))))

(define-syntax conda
  (syntax-rules (else)
    ((_) fail)
    ((_ (else g0 g ...)) (all g0 g ...))
    ((_ (g0 g ...) c ...)
     (ifa g0 (all g ...) (conda c ...)))))

(define-syntax condu
  (syntax-rules (else)
    ((_) fail)
    ((_ (else g0 g ...)) (all g0 g ...))
    ((_ (g0 g ...) c ...)
     (ifu g0 (all g ...) (condu c ...)))))

(define-syntax ifa
  (syntax-rules ()
    ((_ g0 g1 g2)
     (lambdag@ (s)
       (let ((s-inf (g0 s)) (g^ g1))
         (case-inf s-inf
           (g2 s)
           ((s) (g^ s))
           ((s f) (bind s-inf g^))))))))

(define-syntax ifu
  (syntax-rules ()
    ((_ g0 g1 g2)
     (lambdag@ (s)
       (let ((s-inf (g0 s)) (g^ g1))
         (case-inf s-inf
           (g2 s)
           ((s) (g^ s))
           ((s f) (g^ s))))))))

;; ------

(define-syntax run*
  (syntax-rules ()
    ((_ (x) g ...) (run #f (x) g ...))))

(define-syntax lambda-limited
  (syntax-rules ()
    ((_ n formals g)
     (let ((x (var 'x)))
       (lambda formals
         (ll n x g))))))

(define ll
  (lambda (n x g)
    (lambdag@ (s)
      (let ((v (walk x s)))
        (cond
          ((var? v) (g (ext-s x 1 s)))
          ((< v n) (g (ext-s x (+ v 1) s)))
          (else (fail s)))))))

(define-syntax project
  (syntax-rules ()
    ((_ (x ...) g ...)
     (lambdag@ (s)
       (let ((x (walk* x s)) ...)
         ((all g ...) s))))))

(display "- with: minikanren/mk.scm\n")

;; 'o' for goal

(define-syntax ando+
  (syntax-rules ()
    [(_ name-list . body)
     (fresh name-list . body)]))

(define-syntax oro+
  (syntax-rules ()
    [(_ name-list
        a
        ...)
     (fresh name-list
       (conde
         [a]
         ...))]))

(define-syntax ando
  (syntax-rules ()
    [(_ . body)
     (ando+ () . body)]))

(define-syntax oro
  (syntax-rules ()
    [(_ . body)
     (oro+ () . body)]))

(define conso
  (lambda (a d p)
    (== (cons a d) p)))

(define caro
  (lambda (p a)
    (fresh (d)
      (== (cons a d) p))))

(define cdro
  (lambda (p d)
    (fresh (a)
      (== (cons a d) p))))

(define pairo
  (lambda (p)
    (fresh (a d)
      (== (cons a d) p))))

(define nullo
  (lambda (x)
    (== x '())))

;; (define listo
;;   (lambda (l)
;;     (conde
;;       [(nullo l) succeed]
;;       [(pairo l) (fresh (d)
;;                    (cdro l d)
;;                    (listo d))]
;;       [else fail])))

(define listo
  (lambda (l)
    (oro
      (nullo l)
      (ando+ (d)
        (pairo l)
        (cdro l d)
        (listo d)))))

(display "- with: basic o\n")

;; (get-collects-search-dirs)
;; (find-user-collects-dir)
