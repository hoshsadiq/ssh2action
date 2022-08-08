# SSH to Actions

This GitHub Action allows you to connect to GitHub Actions VM via SSH for interactive debugging. Internally, it uses tmate to allow you to establish a connection.

## Usage

```yaml
- name: Start SSH via tmate
  uses: hoshsadiq/ssh2actions@main
```

After running this, the action will give you an ssh connection string. Please note: you must authenticate using any of the private ssh key of the GitHub Actions Actor that have been linked  to GitHub.

## License

[MIT](https://github.com/hoshsadiq/ssh2actions/blob/main/LICENSE) © Hosh Sadiq
