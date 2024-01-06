AC_INIT([arc-toolchain],[1.0])


AC_ARG_WITH(gcc,
		[AS_HELP_STRING([--with-gcc=SIM],
		[Sets the base ARC Simulator @<:@--with-cpu=qemu@:>@])],
		[],
		[with_gcc=default]
		)

AS_IF([test "x$with_gcc" != xdefault],
	    [AC_SUBST(with_gcc, $with_gcc)])


AC_ARG_WITH(target-triplet,
		[AS_HELP_STRING([--with_target_triplet=SIM],
		[Sets the base ARC Simulator @<:@--with-cpu=qemu@:>@])],
		[],
		[with_target_triplet=default]
		)

AS_IF([test "x$with_target_triplet" != xdefault],
	    [AC_SUBST(with_target_triplet, $with_target_triplet)])


AC_ARG_WITH(target-alias,
		[AS_HELP_STRING([--with_target_alias=SIM],
		[Sets the base ARC Simulator @<:@--with-cpu=qemu@:>@])],
		[],
		[with_target_alias=default]
		)

AS_IF([test "x$with_target_alias" != xdefault],
	    [AC_SUBST(with_target_alias, $with_target_alias)])

AC_CONFIG_FILES([Makefile])

AC_OUTPUT