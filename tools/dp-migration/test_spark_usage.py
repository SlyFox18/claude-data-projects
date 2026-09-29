from spark_usage import core_seconds


def test_step_integral_of_allocated_cores():
    data = {"timestamps": [0, 1000, 3000, 4000], "allocatedCores": [8.0, 16.0, 8.0, 8.0]}
    # 8 cores for 1 s + 16 cores for 2 s + 8 cores for 1 s = 48 core-seconds
    assert core_seconds(data) == 48.0


def test_empty_timeline():
    assert core_seconds({"timestamps": [], "allocatedCores": []}) == 0.0
