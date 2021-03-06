module: objective-c
synopsis: Some basics for talking to the Objective C 2 runtime.
author: Bruce Mitchener, Jr.
copyright: See LICENSE file in this distribution.

define constant $shadow-class-registry :: <table> = make(<table>);
define constant $class-registry :: <table> = make(<table>);

define C-subtype <objc/class> (<C-statically-typed-pointer>)
end;

define sealed method \=
    (class1 :: <objc/class>, class2 :: <objc/class>)
 => (equal? :: <boolean>)
  class1.pointer-address = class2.pointer-address
end;

define sideways method print-object
    (c :: <objc/class>, stream :: <stream>)
 => ()
  format(stream, "{<objc/class> %s}", objc/class-name(c));
end;

define function objc/register-shadow-class
    (objc-class :: <objc/class>, shadow-class :: subclass(<objc/instance>))
 => ()
  $shadow-class-registry[objc-class.pointer-address] := shadow-class;
  $class-registry[shadow-class] := objc-class;
end;

define function objc/shadow-class-for
    (raw-objc-class :: <machine-word>)
 => (shadow-class :: subclass(<objc/instance>))
  let shadow-class = element($shadow-class-registry, raw-objc-class, default: #f);
  let found
    = if (shadow-class)
        #t
      else
        format-err("WARNING:  objc/shadow-class-for:  No shadow class for %s.\n", objc/class-name(raw-objc-class));
        force-err();
        raw-objc-class := objc/raw-super-class(raw-objc-class);
        #f
      end;
  until (found | ~raw-objc-class)
    shadow-class := element($shadow-class-registry, raw-objc-class, default: #f);
    if (shadow-class)
      format-err("WARNING:  objc/shadow-class-for:  Using %s instead.\n", objc/class-name(raw-objc-class));
      force-err();
      found := #t;
    else
      raw-objc-class := objc/raw-super-class(raw-objc-class);
    end;
  end;
  shadow-class | <NSObject>;
end;

define function objc/class-for-shadow
    (shadow-class :: subclass(<objc/instance>))
 => (objc-class :: <objc/class>)
  $class-registry[shadow-class]
end;

define function objc/get-class (name :: <string>)
 => (objc-class :: false-or(<objc/class>))
  let raw-objc-class
    = primitive-wrap-machine-word
        (primitive-cast-pointer-as-raw
          (%call-c-function ("objc_getClass")
                (name :: <raw-byte-string>)
             => (object :: <raw-c-pointer>)
              (primitive-string-as-raw(name))
           end));
  if (raw-objc-class ~= 0)
    make(<objc/class>, address: raw-objc-class)
  else
    #f
  end if
end;

define inline function objc/super-class (objc-class :: <objc/class>)
 => (objc-class :: false-or(<objc/class>))
  let raw-objc-class
    = primitive-wrap-machine-word
        (primitive-cast-pointer-as-raw
          (%call-c-function ("class_getSuperclass")
                (objc-class :: <raw-c-pointer>)
             => (objc-class :: <raw-c-pointer>)
                (primitive-unwrap-c-pointer(objc-class))
           end));
  if (raw-objc-class ~= 0)
    make(<objc/class>, address: raw-objc-class)
  else
    #f
  end if
end;

define inline function objc/raw-super-class (raw-objc-class :: <machine-word>)
 => (raw-objc-class :: <machine-word>)
  primitive-wrap-machine-word
    (primitive-cast-pointer-as-raw
      (%call-c-function ("class_getSuperclass")
            (objc-class :: <raw-c-pointer>)
         => (objc-class :: <raw-c-pointer>)
            (primitive-cast-raw-as-pointer(primitive-unwrap-machine-word(raw-objc-class)))
       end))
end;

define inline method objc/class-name (objc-class :: <objc/class>)
 => (objc-class-name :: <string>)
  primitive-raw-as-string
      (%call-c-function ("class_getName")
            (objc-class :: <raw-c-pointer>)
         => (name :: <raw-byte-string>)
            (primitive-unwrap-c-pointer(objc-class))
       end)
end;

define inline method objc/class-name (raw-objc-class :: <machine-word>)
 => (objc-class-name :: <string>)
  primitive-raw-as-string
      (%call-c-function ("class_getName")
            (objc-class :: <raw-c-pointer>)
         => (name :: <raw-byte-string>)
            (primitive-cast-raw-as-pointer(primitive-unwrap-machine-word(raw-objc-class)))
       end)
end;

define inline function objc/class-responds-to-selector?
    (objc-class :: <objc/class>, selector :: <objc/selector>)
 => (well? :: <boolean>)
  primitive-raw-as-boolean
    (%call-c-function ("class_respondsToSelector")
        (objc-class :: <raw-c-pointer>,
         selector :: <raw-c-pointer>)
     => (well? :: <raw-boolean>)
      (primitive-unwrap-c-pointer(objc-class),
       primitive-unwrap-c-pointer(selector))
    end);
end;

define inline function objc/instance-size (objc-class :: <objc/class>)
 => (objc-instance-size :: <integer>)
  raw-as-integer
      (%call-c-function ("class_getInstanceSize")
            (objc-class :: <raw-c-pointer>)
         => (size :: <raw-machine-word>)
          (primitive-unwrap-c-pointer(objc-class))
       end)
end;

define inline function objc/get-class-method
    (objc-class :: <objc/class>, selector :: <objc/selector>)
 => (method? :: false-or(<objc/method>))
  let raw-method
    = primitive-wrap-machine-word
        (primitive-cast-pointer-as-raw
          (%call-c-function ("class_getClassMethod")
               (objc-class :: <raw-c-pointer>,
                selector :: <raw-c-pointer>)
            => (method? :: <raw-c-pointer>)
             (primitive-unwrap-c-pointer(objc-class),
              primitive-unwrap-c-pointer(selector))
           end));
  if (raw-method ~= 0)
    make(<objc/method>, address: raw-method)
  else
    #f
  end if
end;

define inline function objc/get-instance-method
    (objc-class :: <objc/class>, selector :: <objc/selector>)
 => (method? :: false-or(<objc/method>))
  let raw-method
    = primitive-wrap-machine-word
        (primitive-cast-pointer-as-raw
          (%call-c-function ("class_getInstanceMethod")
               (objc-class :: <raw-c-pointer>,
                selector :: <raw-c-pointer>)
            => (method? :: <raw-c-pointer>)
             (primitive-unwrap-c-pointer(objc-class),
              primitive-unwrap-c-pointer(selector))
           end));
  if (raw-method ~= 0)
    make(<objc/method>, address: raw-method)
  else
    #f
  end if
end;

define inline function objc/allocate-class-pair
    (super-class :: subclass(<objc/instance>),
     class-name :: <string>)
 => (objc-class :: <objc/class>)
  let super-class = objc/class-for-shadow(super-class);
  let raw-class
    = primitive-wrap-machine-word
        (primitive-cast-pointer-as-raw
          (%call-c-function ("objc_allocateClassPair")
               (super-class :: <raw-c-pointer>,
                class-name :: <raw-byte-string>,
                extra-bytes :: <raw-machine-word>)
            => (objc-class :: <raw-c-pointer>)
             (primitive-unwrap-c-pointer(super-class),
              primitive-string-as-raw(class-name),
              integer-as-raw(0))
           end));
  make(<objc/class>, address: raw-class)
end;

define inline function objc/register-class-pair
    (objc-class :: <objc/class>)
 => ()
  %call-c-function ("objc_registerClassPair")
      (objc-class :: <raw-c-pointer>)
   => (nothing :: <raw-c-void>)
    (primitive-unwrap-c-pointer(objc-class))
  end;
end;

define inline function objc/add-method
    (objc-class :: <objc/class>,
     selector :: <objc/selector>,
     implementation :: <c-function-pointer>,
     types :: <string>)
 => (added? :: <boolean>)
  primitive-raw-as-boolean
    (%call-c-function ("class_addMethod")
         (objc-class :: <raw-c-pointer>,
          selector :: <raw-c-pointer>,
          implementation :: <raw-c-pointer>,
          types :: <raw-byte-string>)
      => (added? :: <raw-boolean>)
       (primitive-unwrap-c-pointer(objc-class),
        primitive-unwrap-c-pointer(selector),
        primitive-unwrap-c-pointer(implementation),
        primitive-string-as-raw(types))
     end)
end;

define inline method objc/conforms-to-protocol?
    (objc-class :: <objc/class>,
     protocol :: <objc/protocol>)
 => (conforms? :: <boolean>)
  primitive-raw-as-boolean
    (%call-c-function ("class_conformsToProtocol")
         (objc-class :: <raw-c-pointer>,
          protocol :: <raw-c-pointer>)
      => (conforms? :: <raw-boolean>)
       (primitive-unwrap-c-pointer(objc-class),
        primitive-unwrap-c-pointer(protocol))
     end)
end;

define inline method objc/add-protocol
    (objc-class :: <objc/class>,
     protocol :: <objc/protocol>)
 => (added? :: <boolean>)
  primitive-raw-as-boolean
    (%call-c-function ("class_addProtocol")
         (objc-class :: <raw-c-pointer>,
          protocol :: <raw-c-pointer>)
      => (added? :: <raw-boolean>)
       (primitive-unwrap-c-pointer(objc-class),
        primitive-unwrap-c-pointer(protocol))
     end)
end;
