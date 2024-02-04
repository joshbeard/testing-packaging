package main

import (
	"flag"
	"fmt"
	"html/template"
	"math"
	"os"
	"path/filepath"
	"strings"

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
	Dirs  []File
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

	// if args.prefix == "/" {
	// 	args.prefix = ""
	// }

	args.prefix = strings.Trim(args.prefix, "/")

	sess := session.Must(session.NewSession())
	svc := s3.New(sess)

	req := &s3.ListObjectsV2Input{
		Bucket: aws.String(args.bucket),
		Prefix: aws.String(args.prefix),
	}

	var dirs []File
	var files []File
	err := svc.ListObjectsV2Pages(req, func(page *s3.ListObjectsV2Output, lastPage bool) bool {
		for _, obj := range page.Contents {
			if shouldSkip(*obj.Key) {
				continue
			}

			// Trim the prefix from the key.
			trimmed := strings.TrimPrefix(*obj.Key, args.prefix)
			if strings.Contains(trimmed, "/") {
				dir := filepath.Dir(trimmed)
				if !containsFile(dirs, dir+"/") {
					dirs = append(dirs, File{
						Name: dir + "/",
						URL:  args.url + "/" + args.prefix + dir,
					})
				}
			}

			files = append(files, File{
				Name:         filepath.Base(*obj.Key),
				Size:         humanizeBytes(*obj.Size),
				LastModified: obj.LastModified.Format("2006-01-02 15:04 UTC"),
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
		Dirs:  dirs,
	}

	wr := new(strings.Builder)
	if err := tmpl.Execute(wr, data); err != nil {
		panic(err)
	}

	if args.upload {
		fmt.Println("Uploading index.html to S3...")
		if err := uploadToS3(svc, args.bucket, wr, args.prefix+"/index.html"); err != nil {
			panic(err)
		}
		return
	}

	// fmt.Println(wr.String())
	fmt.Println("Directories:")
	for _, d := range dirs {
		fmt.Printf("  %s\n", d.Name)
	}

	fmt.Println("Files:")
	for _, f := range files {
		fmt.Printf("  %s\n", f.Name)
	}

}

func containsFile(arr []File, s string) bool {
	for _, a := range arr {
		if a.Name == s {
			return true
		}
	}
	return false
}

func shouldSkip(key string) bool {
	// keySlashes := strings.Count(key, "/")
	// prefixSlashes := strings.Count(args.prefix, "/")
	//
	// fmt.Printf("key: %s; keySlashes %d; prefixSlashes: %d\n", key, keySlashes, prefixSlashes)
	// if !args.recursive && (args.prefix == "" && keySlashes > 1) {
	// 	// args.prefix != "" && keySlashes > prefixSlashes+1) {
	// 	return true
	// }
	trimmed := strings.TrimPrefix(key, args.prefix+"/")
	if strings.Contains(trimmed, "/") {
		fmt.Printf("skipping: %s [prefix %s]\n", key, args.prefix)
		return true
	}

	if strings.HasSuffix(key, "index.html") {
		return true
	}

	// fmt.Printf("key: %s; prefix: %s\n", key, args.prefix)
	return false
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
