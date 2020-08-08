# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line.
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
SOURCEDIR     = source
BUILDDIR      = build

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: help Makefile

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	#Generate files from source
	#Verification Docs
	python3 get_rst.py -i ../verif/slink/tb_top/slink_tb_top.v   -o source/slink_tb_top.rst
	python3 get_rst.py -i ../verif/slink/tests/slink_tests.vh    -o source/slink_tests.inc
	python3 get_rst.py -i ../verif/slink/sub/slink_app_driver.v  -o source/slink_app_driver.inc
	python3 get_rst.py -i ../verif/slink/sub/slink_app_monitor.v -o source/slink_app_monitor.inc
	
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
