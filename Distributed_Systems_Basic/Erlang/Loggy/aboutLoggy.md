# Loggy: a logical time logger

The task is to implement a logging procedure that receives log events from
a set of workers. The events are tagged with the Lamport time stamp of
the worker and the events must be ordered before written to stdout.
