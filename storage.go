package main

import ()

type Storage interface {
	Put(key, value string) error
	Get(key string) (string, error)
	Close()
}
