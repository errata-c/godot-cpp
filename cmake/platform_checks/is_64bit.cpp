#include <cinttypes>

// This will fail to compile if pointer type is not 64 bit.
static_assert(sizeof(nullptr) == sizeof(uint64_t), "");

int main(int argc, char* argv[]) {
	return 0;
}