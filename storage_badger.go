package main

import (
	"github.com/dgraph-io/badger"
	log "github.com/sirupsen/logrus"
)

type StorageBadger struct {
	*badger.DB
}

func NewStorage() *StorageBadger {
	db, err := badger.Open(badger.DefaultOptions("patientDB"))
	if err != nil {
		panic(err)
	}
	return &StorageBadger{
		db,
	}
}

func (s *StorageBadger) Close() {
	log.Println("Closing DB")
	s.Close()
}

func (s *StorageBadger) Put(key, value string) error {

	txn := s.NewTransaction(true)
	err := txn.Set([]byte(key), []byte(value))
	if err != nil {
		return err
	}

	// Commit the transaction and check for error.
	if err := txn.Commit(); err != nil {
		return err
	}

	return nil
}

func (s *StorageBadger) Get(key string) (string, error) {

	retval := make([]byte, 0)

	err := s.View(func(txn *badger.Txn) error {
		item, err := txn.Get([]byte(key))
		if err != nil {
			return err
		}

		retval, err = item.ValueCopy(nil)
		if err != nil {
			return err
		}

		return nil
	})
	return string(retval), err
}
