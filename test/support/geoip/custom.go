package main

import (
	"log"
	"net"
	"os"

	"github.com/maxmind/mmdbwriter"
	"github.com/maxmind/mmdbwriter/mmdbtype"
)

func main() {
	writer, err := mmdbwriter.New(
		mmdbwriter.Options{
			DatabaseType: "GeoLite2-City",
			RecordSize:   24,
		},
	)
	if err != nil {
		log.Fatal(err)
	}

	_, network, err := net.ParseCIDR("1.0.0.1/32")
	if err != nil {
		log.Fatal(err)
	}
	record := mmdbtype.Map{
		"continent": mmdbtype.Map{
			"code":       mmdbtype.String("AS"),
			"geoname_id": mmdbtype.Uint64(6255147),
			"names": mmdbtype.Map{
				"en": mmdbtype.String("Asia"),
			},
		},
		"location": mmdbtype.Map{
			"accuracy_radius": mmdbtype.Uint16(1000),
			"latitude":        mmdbtype.Float64(35.0),
			"longitude":       mmdbtype.Float64(105.0),
			"time_zone":       mmdbtype.String("Australia/Perth"),
		},
	}
	err = writer.Insert(network, record)
	if err != nil {
		log.Fatal(err)
	}

	fh, err := os.Create("custom.mmdb")
	if err != nil {
		log.Fatal(err)
	}

	_, err = writer.WriteTo(fh)
	if err != nil {
		log.Fatal(err)
	}
}
