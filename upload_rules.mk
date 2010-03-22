# License: GPL v2
# Copyright Red Hat Inc. 2008

ifdef UPLOAD_URL
upload:
	@url="$(UPLOAD_URL)"; \
	case "$$url" in \
	ssh://*) \
		url="$${url#ssh://}"; \
		userhostname="$${url%%/*}"; \
		path="$${url#*/}"; \
		echo Copying "$(PKGNAME)-$(PKGVERSION).tar.gz" to "$$userhostname:$$path"; \
		scp "$(PKGNAME)-$(PKGVERSION).tar.gz" "$$userhostname:$$path"; \
		;; \
	*) \
		echo Unknown method. >&2; \
		exit 1; \
		;; \
	esac
endif
