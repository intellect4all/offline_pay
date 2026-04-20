package main

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"os"
	"strings"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/term"

	"github.com/intellect/offlinepay/internal/config"
	adminsvc "github.com/intellect/offlinepay/internal/service/admin"
)

func cmdAdminCreate(ctx context.Context, cfg config.Config, args []string) error {
	fs := flag.NewFlagSet("admin-create", flag.ContinueOnError)
	email := fs.String("email", "", "admin email (required)")
	fullName := fs.String("name", "", "full name")
	rolesCSV := fs.String("roles", "SUPERADMIN", "comma-separated role names")
	passwordArg := fs.String("password", "", "password (omit to prompt)")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *email == "" {
		return fmt.Errorf("--email required")
	}
	password := *passwordArg
	if password == "" {
		var err error
		password, err = promptPassword("Password: ")
		if err != nil {
			return err
		}
		confirm, err := promptPassword("Confirm: ")
		if err != nil {
			return err
		}
		if confirm != password {
			return fmt.Errorf("passwords do not match")
		}
	}
	if len(password) < 12 {
		return fmt.Errorf("password must be at least 12 characters")
	}

	pool, err := pgxpool.New(ctx, cfg.DBURL)
	if err != nil {
		return fmt.Errorf("pgxpool: %w", err)
	}
	defer pool.Close()

	svc := adminsvc.New(pool, adminsvc.JWTSigner{TTL: 15 * time.Minute}, 168*time.Hour)
	roles := splitRoles(*rolesCSV)
	u, err := svc.CreateAdmin(ctx, *email, *fullName, password, roles)
	if err != nil {
		return fmt.Errorf("create admin: %w", err)
	}
	fmt.Printf("created admin %s (id=%s, roles=%v)\n", u.Email, u.ID, roles)
	return nil
}

func promptPassword(prompt string) (string, error) {
	fmt.Fprint(os.Stderr, prompt)
	if term.IsTerminal(int(syscall.Stdin)) {
		b, err := term.ReadPassword(int(syscall.Stdin))
		fmt.Fprintln(os.Stderr)
		if err != nil {
			return "", err
		}
		return string(b), nil
	}
	r := bufio.NewReader(os.Stdin)
	line, err := r.ReadString('\n')
	return strings.TrimRight(line, "\n"), err
}

func splitRoles(csv string) []string {
	out := []string{}
	for _, p := range strings.Split(csv, ",") {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
