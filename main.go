package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"unicode"

	"github.com/gorilla/mux"
	log "github.com/sirupsen/logrus"
	"github.com/urfave/negroni"
	"golang.org/x/text/runes"
	"golang.org/x/text/transform"
	"golang.org/x/text/unicode/norm"
)

var storage Storage

func main() {
	mux := mux.NewRouter()
	mux.HandleFunc("/ping", func(w http.ResponseWriter, req *http.Request) {
		fmt.Fprintf(w, "Service running")
	})
	mux.HandleFunc("/patient/{dateofbirth}/{name}", getPatient).Methods(http.MethodGet)
	mux.HandleFunc("/patient", storePatient).Methods(http.MethodPost)

	n := negroni.Classic() // Includes some default middlewares
	n.UseHandler(mux)

	storage = NewStorage()
	defer storage.Close()

	listenAddr := os.Getenv("LISTEN_ADDR")
	log.Fatal(http.ListenAndServe(listenAddr, n))
}

func getPatient(w http.ResponseWriter, r *http.Request) {

	vars := mux.Vars(r)
	dateofbirth := vars["dateofbirth"]
	name := vars["name"]

	key := fmt.Sprintf("%s:%s", dateofbirth, sanitizeName(name))
	log.Printf("Looking for %s", key)
	result, err := storage.Get(key)
	if err != nil {
		w.WriteHeader(500)
		w.Write([]byte(err.Error()))
	}
	w.Write([]byte(result))
}

func storePatient(w http.ResponseWriter, r *http.Request) {
	body := r.Body
	defer body.Close()

	dec := json.NewDecoder(body)
	dec.DisallowUnknownFields()

	var jsonIn struct {
		Name      string `json:"name"`
		DoB       string `json:"dateofbirth"`
		PatientID string `json:"patientid"`
	}

	err := dec.Decode(&jsonIn)
	if err != nil {
		fmt.Println(err)
		w.WriteHeader(500)
		return
	}

	key := fmt.Sprintf("%s:%s", jsonIn.DoB, sanitizeName(jsonIn.Name))

	storage.Put(key, jsonIn.PatientID)

	w.Write([]byte(key))
}

func sanitizeName(name string) string {
	name = strings.ToLower(strings.Replace(name, "^", ":", -1))
	t := transform.Chain(norm.NFD, runes.Remove(runes.In(unicode.Diacritic)), runes.Remove(runes.In(unicode.Dash)), norm.NFC)
	result, _, _ := transform.String(t, name)
	return result
}
