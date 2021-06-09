
.PHONY: docker
docker:
	docker build -t liberlang .

.PHONY: all
all:
	git clone --depth 1 https://github.com/diodechain/otp.git
