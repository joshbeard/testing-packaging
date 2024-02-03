package main

import (
	"flag"
	"fmt"
	"html/template"
	"math"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

type cliArgs struct {
	bucket    string
	prefix    string
	title     string
	recursive bool
	upload    bool
	url       string
}

var args cliArgs

// File represents a file in the S3 bucket.
type File struct {
	Name         string
	Size         string
	LastModified string
	URL          string
}

// Data holds the template data.
type Data struct {
	Title string
	Files []File
}

func main() {
	flag.StringVar(&args.bucket, "bucket", "", "The name of the S3 bucket")
	flag.StringVar(&args.prefix, "prefix", "", "The path within the bucket to list")
	flag.StringVar(&args.title, "title", "", "The title of the index page")
	flag.BoolVar(&args.recursive, "recursive", false, "List objects recursively")
	flag.BoolVar(&args.upload, "upload", false, "Upload a file to the S3 bucket")
	flag.StringVar(&args.url, "url", "", "The URL of the S3 bucket")
	flag.Parse()

	if args.bucket == "" {
		flag.Usage()
		os.Exit(1)
	}

	if args.prefix == "/" {
		args.prefix = ""
	}

	sess := session.Must(session.NewSession())
	svc := s3.New(sess)

	req := &s3.ListObjectsV2Input{
		Bucket: aws.String(args.bucket),
		Prefix: aws.String(args.prefix),
	}

	var files []File
	err := svc.ListObjectsV2Pages(req, func(page *s3.ListObjectsV2Output, lastPage bool) bool {
		for _, obj := range page.Contents {
			key := *obj.Key
			// Skip if not recursive and the object key is beyond the current prefix level
			if !args.recursive && (args.prefix == "" && strings.Count(key, "/") > 0 ||
				args.prefix != "" && strings.Count(key, "/") > strings.Count(args.prefix, "/")) {
				continue
			}

			files = append(files, File{
				Name:         filepath.Base(*obj.Key),
				Size:         humanizeBytes(*obj.Size),
				LastModified: obj.LastModified.Format(time.RFC822),
				URL:          args.url + "/" + *obj.Key,
			})
		}
		return true
	})
	if err != nil {
		panic(err)
	}

	tmpl, err := template.ParseFiles("index.html.tmpl")
	if err != nil {
		panic(err)
	}

	data := Data{
		Title: args.title,
		Files: files,
	}

	wr := new(strings.Builder)
	if err := tmpl.Execute(wr, data); err != nil {
		panic(err)
	}

	if args.upload {
		fmt.Println("Uploading index.html to S3...")
		if err := uploadToS3(svc, args.bucket, wr, "index.html"); err != nil {
			panic(err)
		}
		return
	}

	fmt.Println(wr.String())
}

func uploadToS3(svc *s3.S3, bucket string, content *strings.Builder, dst string) error {
	r := strings.NewReader(content.String())
	f := aws.ReadSeekCloser(r)

	// Upload as an html file. No ACL is set, so the default ACL of the bucket will be used.
	_, err := svc.PutObject(&s3.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(dst),
		Body:        f,
		ContentType: aws.String("text/html"),
		// ContentDisposition: aws.String("inline"),
		ContentEncoding: aws.String("utf-8"),
		ContentLanguage: aws.String("en"),
		ContentLength:   aws.Int64(int64(r.Len())),
	})

	return err
}

// HumanizeBytes converts bytes to a human-readable format.
func humanizeBytes(bytes int64) string {
	units := []string{"B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"}
	if bytes < 10 {
		return fmt.Sprintf("%d B", bytes)
	}
	log := math.Log(float64(bytes)) / math.Log(1024)
	index := int(log)
	size := float64(bytes) / math.Pow(1024, float64(index))
	return fmt.Sprintf("%.2f %s", size, units[index])
}
